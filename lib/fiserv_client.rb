module PagafasilImporters

  class FiservClient

    class FiservServiceError < RuntimeError; end
    class ApiArgumentError < RuntimeError; end

    # TEST ACCOUNTS:
    #
    # SV 8800000015
    # SV 8800000016
    # SV 8800000017
    # DD 9900003588
    # DD 9900003589
    # DD 9900003590
    #
    # GL 270900000006

    # PagafasilImporters::FiservClient.new.balance 'DD', '9900003588'
    def balance account_type, account_id
      acct_id = {
        "DepAcctId" =>
          {
            "AcctId" => account_id,
            "AcctType" => account_type
          }
      }

      req = {
        "BankSvcRq" => {
          "RqUID"   => SecureRandom.uuid,
          "SPName"  => "FiservICBS",
          "AcctInqRq" => {
            "RqUID" => SecureRandom.uuid,
            # "IncExtBal"=>"1",
            "IncBal"=>"1"
          }.merge(acct_id)
        }
      }
      resp = api_call req

      all_balances = resp.dig('IFX', 'BankSvcRs', 'AcctInqRs', 'AcctBal')
      if all_balances
        balances = all_balances.
          select{|b| ['Current', 'Avail'].include?(b['BalType'])}.
          map do |b|
            balance_type =
              case b['BalType']
              when 'Current'
                'current'
              when 'Avail'
                'available'
              else
                raise "unhandled BalType for #{b}"
              end

            cur_amt = b['CurAmt'] || raise("CurAmt not present in response for #{b}")
            {
              type: balance_type,
              amount: cur_amt['Amt'].gsub('.', '').to_i,
              currency: cur_amt['CurCode']
            }
          end

        rv = {
          status: 'approved',
          balances: balances,
          raw_response: resp
        }
      else
        rv = extract_declined_response(resp)
      end

      rv
    end

    # PagafasilImporters::FiservClient.new.transfer rand(10**12), 'DD', '9900003588', 'DD', '9900003589', 1, 'ANG'
    # PagafasilImporters::FiservClient.new.transfer rand(10**12), 'SV', '8800000015', 'SV', '8800000016', 30, 'ANG'
    # PagafasilImporters::FiservClient.new.transfer rand(10**12), 'SV', '8800000015', 'DD', '9900003588', 40, 'ANG'
    def transfer transaction_id, src_account_type, src_account_id, dest_account_type, dest_account_id, amount, currency, options = {}
      amount = (amount.to_f / 100).round(2)
      xfer_info = {
        "CurAmt"  =>  { "Amt" => amount, "CurCode" => currency },
      }

      if src_account_type == 'GL'
        xfer_info.merge!("GLAcctIdFrom" => {
            "AcctId" => src_account_id,
            "AcctType" => src_account_type,
            "CostCenter" => "00001",
            "CurCode" => "000",
          })
      else
        xfer_info.merge!("DepAcctIdFrom" => { "AcctId" => src_account_id,  "AcctType" => src_account_type })
      end

      if dest_account_type == 'GL'
        xfer_info.merge!("GLAcctIdTo" => {
            "AcctId" => dest_account_id,
            "AcctType" => dest_account_type,
            "CostCenter" => "00001",
            "CurCode" => "000",
          })
      else
        xfer_info.merge!("DepAcctIdTo"   => { "AcctId" => dest_account_id, "AcctType" => dest_account_type },)
      end

      req = {
        "MonSvcRq" => {
          "RqUID"  => SecureRandom.uuid,
          "SPName" => "FiservICBS",
          "GLAppXferAddRq" => {
            "RqUID" => SecureRandom.uuid,
            "TrnCommon" => { "TrnCode" => map_trn_code(src_account_type, dest_account_type), "SeqId" => transaction_id },
            "XferInfo"  => xfer_info
          }
        }
      }
      resp = api_call req

      if resp.dig('IFX', 'MonSvcRs', 'GLAppXferAddRs', 'ResponseCode') == 'Accepted'
        rv = {
          status: 'approved',
          raw_response: resp
        }
      else
        rv = extract_declined_response(resp)
      end

      rv
    end


    private


    def api_call request
      conn = faraday_factory
      request_xml = build_raw_request(request)
      LOGGER.debug "FISERV REQUEST: #{request_xml}"

      http_response = conn.post do |req|
        req.url ''
        req.headers['Content-Type'] = 'text/xml; charset=utf-8'
        req.body = request_xml
      end

      response = Hash.from_xml http_response.body
      LOGGER.debug "FISERV RESPONSE: #{http_response.body}"
      response
    end

    # TODO: validate these values
    def build_raw_request message
      WebPay.opts[:fiserv_header_hash].
        merge(message).
        to_xml(root: 'IFX')
    end

    def faraday_factory
      conn = Faraday.new(:url => WebPay.opts[:fiserv_url]) do |builder|
        builder.adapter Faraday::Adapter::NetHttp
        # builder.response :logger, ::Logger.new(STDOUT), bodies: true
      end
      conn
    end

    # Host transaction code. When using Alias accounts, provide transaction code. [
    # DD to DD - TC 51CC, DD to SV - TC 51CS, DD to TM - TC 51CT, DD to LN - TC 51CL, DD to GL - TC 51CG,
    # SV to DD - TC 51SC, SV to SV - TC 51SS, SV to TM - TC 51ST, SV to LN - TC 51SL, SV to GL - TC 51SG,
    # GL to DD - TC 51GC. GL to SV - TC 51GS, GL to TM 51GT, GL to GL - TC 51GL, LN to DD - TC 51LC,
    # LN to SV - TC 51LS, LN to TM - TC 51LT, LN to LN - TC 51LL, LN to GL - TC 51LG, TM to DD - TC 51TS,
    # TM to SV - TC 51TS, TM to TM - TC 51TT, TM to LN TC 51TL, TM to GL - TC 51TG]
    def map_trn_code src_account_type, dest_account_type
      rv = ACCOUNT_TYPES_TO_HOST_TRN_CODE[[src_account_type, dest_account_type]]
      if rv
        return rv
      else
        raise ApiArgumentError.new("unsupported transfer account types, src: #{src_account_type} dest: #{dest_account_type}")
      end
    end

    def extract_declined_response resp
      general_status = resp.dig('IFX', 'GeneralStatus') || {}
      response_code = general_status['ErrNum'] || general_status['StatusCode'] || 'UNKNOWN'
      response_message = general_status['ErrDesc'] || general_status['StatusDesc'] || 'UNKNOWN'

      {
        status: 'declined',
        response_code: response_code,
        response_message: response_message,
        general_status: general_status,
        raw_response: resp
      }
    end

    ACCOUNT_TYPES_TO_HOST_TRN_CODE =       {
      ['DD', 'DD'] => '51CC',
      ['DD', 'SV'] => '51CS',
      ['DD', 'TM'] => '51CT',
      ['DD', 'LN'] => '51CL',
      ['DD', 'GL'] => '51CG',
      ['SV', 'DD'] => '51SC',
      ['SV', 'SV'] => '51SS',
      ['SV', 'TM'] => '51ST',
      ['SV', 'LN'] => '51SL',
      ['SV', 'GL'] => '51SG',
      ['GL', 'DD'] => '51GC',
      ['GL', 'SV'] => '51GS',
      ['GL', 'TM'] => '51GT',
      ['GL', 'GL'] => '51GL',
      ['LN', 'DD'] => '51LC',
      ['LN', 'SV'] => '51LS',
      ['LN', 'TM'] => '51LT',
      ['LN', 'LN'] => '51LL',
      ['LN', 'GL'] => '51LG',
      ['TM', 'DD'] => '51TS',
      ['TM', 'SV'] => '51TS',
      ['TM', 'TM'] => '51TT',
      ['TM', 'LN'] => '51TL',
      ['TM', 'GL'] => '51TG',
    }

  end

end

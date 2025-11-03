require 'faraday'
require 'zlib'
require 'stringio'
require 'active_support/core_ext/hash'
# require 'ruby_dig' # not needed for ruby 2.3

module PagafasilImporters

  class PagatinuClient

    class PagatinuServiceError < RuntimeError; end
    class ApiArgumentError < RuntimeError; end

    # Meter Number
    #
    # 04229889888
    # 04167587288
    # 04111111110
    # 04229889888
    # 04167587288
    # 04229889888
    # 04167587288

    # 4.1 Issued Test Meter Numbers Electricity
    # 04257670465 - Active
    # 04252652286 – Minimum Vend amount
    # 04259063131 - Blocked customer
    # 04262549407 - Meter not in the system / Disconnected
    # 04004088094 - Vending server not available
    # 04254372016 - Active

    # 4.5 Issued Test Meter Numbers Water
    # 04040879803 - Active
    # 04040408777– Minimum Vend amount
    # 04040408744 - Blocked customer
    # 04040408769 - Meter not in the system / Disconnected
    # 04004088078 - Vending server not available
    # 04040408751 - Active

    def self.faraday_factory
      conn = Faraday.new(:url => WebPay.opts[:pagatinu_url]) do |builder|
        builder.adapter Faraday::Adapter::NetHttp
        # builder.response :logger, ::Logger.new(STDOUT), bodies: true
      end
      conn
    end

    def self.mock! attrs = {}
      p = new
      p.mock_credit_vend_request attrs
    end

    # PAGATINU_AUTH is of the form USERNAME:PASSWORD
    #
    # Responses:
    #  OK:  {:status=>"approved", :message=>"Credit Purchase successful", :receipt_no=>"VUPSB/2470507", :token=>"01234567890123456789", :units=>"38.2 KWh"}
    #  NOK: {:status=>"declined", :message=>"Meter Not Found"}
    #
    # Exceptions:
    #  ApiArgumentError - error in request arguments
    #  PagatinuServiceError - unexpected response from host
    #
    def credit_vend_request attrs
      attrs = attrs.clone

      pagatinu_authentication = ( ENV['PAGATINU_AUTH'] || 'OPPSB:NEBULATWO' ).split(':')

      raise ApiArgumentError.new("amount is missing") unless attrs[:amount]
      raise ApiArgumentError.new("currency is missing") unless attrs[:currency]
      raise ApiArgumentError.new("meter number is missing") unless attrs[:meter_no]
      raise ApiArgumentError.new("meter number is invalid") unless valid_luhn?(attrs[:meter_no])

      raise ApiArgumentError.new("created_at is missing") unless attrs[:created_at]
      raise ApiArgumentError.new("request_id is missing") unless attrs[:request_id]

      op_name     = h_in! attrs, :op_name,     :text, default: pagatinu_authentication[0]
      op_password = h_in! attrs, :op_password, :text, default: pagatinu_authentication[1..-1].join(':')

      client_id   = h_in! attrs, :client_id,   :attr, default: 'VUPSB'
      terminal_id = h_in! attrs, :terminal_id, :attr, default: '0000000000002'

      created_at  = attrs[:created_at].strftime("%Y%m%d%H%M%S").to_s.encode(xml: :attr)
      request_id  = attrs[:request_id].to_s.encode(xml: :attr)

      meter_no    = h_in! attrs, :meter_no,    :attr
      # <amt value="2000.00" symbol="XCG" />
      amount      = to_money(attrs[:amount]).encode(xml: :attr)
      currency    = attrs[:currency].encode(xml: :attr)

      request_xml = <<-XML
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:sch="http://www.nrs.eskom.co.za/xmlvend/revenue/2.1/schema" xmlns:sch1="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
   <soapenv:Header/>
   <soapenv:Body>
      <sch:creditVendReq>
         <sch1:clientID xsi:type="EANDeviceID" ean=#{client_id} xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" />
         <sch1:terminalID xsi:type="EANDeviceID" ean=#{terminal_id} xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" />
         <sch1:msgID dateTime=#{created_at} uniqueNumber=#{request_id} xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" />
         <sch1:authCred>
            <sch1:opName>#{op_name}</sch1:opName>
            <sch1:password>#{op_password}</sch1:password>
         </sch1:authCred>
         <sch1:idMethod xsi:type="VendIDMethod" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">
            <sch1:meterIdentifier xsi:type="MeterNumber" msno=#{meter_no} />
         </sch1:idMethod>
         <sch:purchaseValue xsi:type="PurchaseValueCurrency" xmlns="http://www.nrs.eskom.co.za/xmlvend/revenue/2.1/schema">
            <amt value=#{amount} symbol=#{currency} />
         </sch:purchaseValue>
      </sch:creditVendReq>
   </soapenv:Body>
</soapenv:Envelope>
      XML

      LOGGER.warn "PAGATINU REQUEST: " + request_xml

      raw_response_xml = api_call request_xml
      LOGGER.warn "PAGATINU RESPONSE: " + raw_response_xml

      response_xml = Hash.from_xml raw_response_xml

      fault = response_xml.dig("Envelope", "Body", "Fault")
      if fault
        err_candidates = []
        err_candidates << fault.dig('detail', 'XMLVendFaultResp', 'fault', 'desc')
        err_candidates << fault.dig('detail', 'XMLVendFaultResp', 'operatorMsg')
        err_candidates << fault['faultstring']
        err_candidates << "Uncaught error returned in response: #{response_xml.inspect}"

        return {
          status: 'declined',
          message: err_candidates.compact.first
        }
      end

      credit_vend_resp = response_xml.dig('Envelope', 'Body', 'creditVendResp')
      raise PagatinuServiceError.new("credit_vend_resp not returned! Got: #{response_xml.inspect}") unless credit_vend_resp

      trx_results = credit_vend_resp.dig('creditVendReceipt', 'transactions', 'tx')
      trx_results = [trx_results] if trx_results.is_a?(Hash)
      raise PagatinuServiceError.new("trx_result not returned! Got: #{credit_vend_resp.inspect}") unless trx_results

      trx_result = trx_results.select{|trx_result| trx_result['xsi:type'] == 'CreditVendTx'}
      raise PagatinuServiceError.new("sane CreditVendTx Tx object not returned! Got: #{trx_results.inspect}") unless trx_result.count == 1
      trx_result = trx_result.first

      credit_token_issue = trx_result['creditTokenIssue']
      raise PagatinuServiceError.new("sane credit_token_issue not returned! Got: #{trx_results.inspect}") unless credit_token_issue

      cust_vend_detail = credit_vend_resp['custVendDetail'] || {}
      meter_detail = credit_token_issue['meterDetail'] || {}
      token = credit_token_issue['token'] || {}
      units = credit_token_issue['units'] || {}

      # => [{"units"=>{"value"=>"28.3", "siUnit"=>"KWh"}, "rate"=>{"value"=>"0.60", "symbol"=>"XCG"}},
      #     {"units"=>{"value"=>"8", "siUnit"=>"KWh"}, "rate"=>{"value"=>"0.64", "symbol"=>"XCG"}}]
      tariff_rates = trx_result.dig('tariffBreakdown', 'steps', 'Step')
      tariff_rates = [tariff_rates] if tariff_rates.is_a?(Hash)

      rv = {}

      rv[:status] = 'approved'
      rv[:message] = credit_vend_resp['operatorMsg']

      rv[:receipt_no] = trx_result['receiptNo']
      rv[:token]   = token['stsCipher']
      rv[:units]   = "#{units['value']} #{units['siUnit']}"
      rv[:resource] = credit_token_issue.dig('resource', 'xsi:type').try(:split, /:/).try(:last).to_s.downcase

      rv[:cust_vend_acct]  = cust_vend_detail['accNo']
      rv[:cust_vend_name]  = cust_vend_detail['name']

      rv[:meter_number] = meter_detail['msno']
      rv[:tariff_name] = trx_result.dig('tariff', 'name')

      rv[:tariff_rates] = tariff_rates.map do |tariff_rate|
        {
          amount:   tariff_rate.dig('rate',   'value'),
          currency: tariff_rate.dig('rate',   'symbol'),
          units:    tariff_rate.dig('units',  'value'),
          si_unit:  tariff_rate.dig('units',  'siUnit'),
        }
      end

      rv
    rescue ApiArgumentError => e
      { :status => "declined", message: e.message }
    end

    # STEP 1: credit-vend
    #   time_now = Time.now; request_id=rand(10**6); p = PagafasilImporters::PagatinuClient.new; rv1 = p.credit_vend_request amount: 10_00, currency: 'XCG', meter_no: '04257670465', created_at: time_now, request_id: request_id
    #
    # STEP 2: last-advice
    #   rv2 = p.last_advice_request created_at: time_now, request_id: request_id
    #
    # Must be equal: rv1 == rv2
    #
    def last_advice_request attrs
      attrs = attrs.clone

      pagatinu_authentication = ( ENV['PAGATINU_AUTH'] || 'OPPSB:NEBULATWO' ).split(':')

      raise ApiArgumentError.new("created_at is missing") unless attrs[:created_at]
      raise ApiArgumentError.new("request_id is missing") unless attrs[:request_id]

      op_name     = h_in! attrs, :op_name,     :text, default: pagatinu_authentication[0]
      op_password = h_in! attrs, :op_password, :text, default: pagatinu_authentication[1..-1].join(':')

      client_id   = h_in! attrs, :client_id,   :attr, default: 'VUPSB'
      terminal_id = h_in! attrs, :terminal_id, :attr, default: '0000000000002'

      original_created_at  = attrs[:created_at].strftime("%Y%m%d%H%M%S").to_s.encode(xml: :attr)
      original_request_id  = attrs[:request_id].to_s.encode(xml: :attr)

      current_created_at = Time.now.strftime("%Y%m%d%H%M%S").to_s.encode(xml: :attr)
      current_request_id = rand(10**6).to_s.encode(xml: :attr)

      request_soap_conlog2 = <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<S:Envelope xmlns:S="http://www.w3.org/2003/05/soap-envelope">
  <S:Body>
    <ns2:adviceReq xmlns:ns2="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" xmlns="http://www.conlog.co.za/xmlvend/base-ext/2.1.1/schema" xmlns:ns3="http://www.nrs.eskom.co.za/xmlvend/revenue/2.1/schema" xmlns:ns4="http://www.nrs.eskom.co.za/xmlvend/meter/2.1/schema" xmlns:ns5="http://www.eskom.co.za/xmlvend/meter-ext/2.1/schema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="ns2:LastRespAdviceReq">
      <ns2:clientID xsi:type="ns2:EANDeviceID" ean=#{client_id} />
      <ns2:terminalID xsi:type="ns2:EANDeviceID" ean=#{terminal_id} />
      <ns2:msgID dateTime=#{current_created_at} uniqueNumber=#{current_request_id} />
      <ns2:authCred>
        <ns2:opName>#{op_name}</ns2:opName>
        <ns2:password>#{op_password}</ns2:password>
      </ns2:authCred>
      <ns2:adviceReqMsgID dateTime=#{original_created_at} uniqueNumber=#{original_request_id} />
    </ns2:adviceReq>
  </S:Body>
</S:Envelope>
      XML

      request_xml = request_soap_conlog2

      LOGGER.warn "PAGATINU REQUEST: " + request_xml

      raw_response_xml = api_call request_xml
      LOGGER.warn "PAGATINU RESPONSE: " + raw_response_xml

      response_xml = Hash.from_xml raw_response_xml

      fault = response_xml.dig("Envelope", "Body", "Fault")
      if fault
        err_candidates = []
        err_candidates << fault.dig('detail', 'XMLVendFaultResp', 'fault', 'desc')
        err_candidates << fault.dig('detail', 'XMLVendFaultResp', 'operatorMsg')
        err_candidates << fault['faultstring']
        err_candidates << "Uncaught error returned in response: #{response_xml.inspect}"

        return {
          status: 'declined',
          message: err_candidates.compact.first
        }
      end

      advice_resp = response_xml.dig('Envelope', 'Body', 'adviceResp', 'lastResponse')
      raise PagatinuServiceError.new("credit_vend_resp not returned! Got: #{response_xml.inspect}") unless advice_resp

      trx_results = advice_resp.dig('creditVendReceipt', 'transactions', 'tx')
      trx_results = [trx_results] if trx_results.is_a?(Hash)
      raise PagatinuServiceError.new("trx_result not returned! Got: #{advice_resp.inspect}") unless trx_results

      trx_result = trx_results.select{|trx_result| trx_result['xsi:type'] =~ /CreditVendTx/}
      raise PagatinuServiceError.new("sane CreditVendTx Tx object not returned! Got: #{trx_results.inspect}") unless trx_result.count == 1
      trx_result = trx_result.first

      credit_token_issue = trx_result['creditTokenIssue']
      raise PagatinuServiceError.new("sane credit_token_issue not returned! Got: #{trx_results.inspect}") unless credit_token_issue

      cust_vend_detail = advice_resp['custVendDetail'] || {}
      meter_detail = credit_token_issue['meterDetail'] || {}
      token = credit_token_issue['token'] || {}
      units = credit_token_issue['units'] || {}

      # => [{"units"=>{"value"=>"28.3", "siUnit"=>"KWh"}, "rate"=>{"value"=>"0.60", "symbol"=>"XCG"}},
      #     {"units"=>{"value"=>"8", "siUnit"=>"KWh"}, "rate"=>{"value"=>"0.64", "symbol"=>"XCG"}}]
      tariff_rates = trx_result.dig('tariffBreakdown', 'steps', 'Step')
      tariff_rates = [tariff_rates] if tariff_rates.is_a?(Hash)

      rv = {}

      rv[:status] = 'approved'
      rv[:message] = advice_resp['operatorMsg']

      rv[:receipt_no] = trx_result['receiptNo']
      rv[:token]   = token['stsCipher']
      rv[:units]   = "#{units['value']} #{units['siUnit']}"
      rv[:resource] = credit_token_issue.dig('resource', 'xsi:type').try(:split, /:/).try(:last).to_s.downcase

      rv[:cust_vend_acct]  = cust_vend_detail['accNo']
      rv[:cust_vend_name]  = cust_vend_detail['name']

      rv[:meter_number] = meter_detail['msno']
      rv[:tariff_name] = trx_result.dig('tariff', 'name')

      rv[:tariff_rates] = tariff_rates.map do |tariff_rate|
        {
          amount:   tariff_rate.dig('rate',   'value'),
          currency: tariff_rate.dig('rate',   'symbol'),
          units:    tariff_rate.dig('units',  'value'),
          si_unit:  tariff_rate.dig('units',  'siUnit'),
        }
      end

      rv
    rescue ApiArgumentError => e
      { :status => "declined", message: e.message }
    end


    def mock_credit_vend_request attrs = {}
      attrs = {
        amount: '12341',
        currency: 'XCG',
        meter_no: '04229889888',
        created_at: Time.now,
        request_id: 39829823
      }.merge(attrs)

      credit_vend_request attrs
    end

    def api_call request_xml
      response = conn.post do |req|
        req.url ''
        req.options.timeout = 125
        req.headers['Content-Type'] = 'text/xml; charset=utf-8'
        req.headers['Accept-Encoding'] = 'gzip,deflate'
        req.headers['SOAPAction'] = 'CreditVendRequest'
        req.body = request_xml
      end

      rv = response.body.to_s

      # decrypt if applicable
      begin
        gz = Zlib::GzipReader.new(StringIO.new(rv))
        rv = gz.read
      rescue Zlib::GzipFile::Error
        # do nothing - let rvs remain rvs
      end

      rv
    end


    private

    def h_in! hash, key, encoding, options = {}
      rv = hash.delete(key) || options[:default] || raise(ApiArgumentError.new("key #{key} is missing!"))
      rv.to_s.encode(xml: encoding)
    end

    def conn
      @conn ||= PagatinuClient.faraday_factory
    end

    def to_money int
      "%.2f" % (int.to_i / 100.0).to_s
    end

    def valid_luhn? cc_number
      number = cc_number.
        gsub(/\D/, ''). # remove non-digits
      reverse  # read from right to left

      sum, i = 0, 0

      number.each_char do |ch|
        n = ch.to_i

        # Step 1
        n *= 2 if i.odd?

        # Step 2
        n = 1 + (n - 10) if n >= 10

        sum += n
        i   += 1
      end

      # Step 3
      (sum % 10).zero?
    end

  end


  class MockPagatinuClient < PagatinuClient

    TEST_METER_NUMBERS = %W( 04229889888 04167587288 04111111110 04229889888 04167587288 04229889888 04167587288 )


    def api_call request_xml
      xml = request_xml.gsub("\n", '') # one-lineize it so regexps work

      if xml =~ /ns2:adviceReq/
        req_type = :last_advice
      elsif xml =~ /sch:creditVendReq/
        req_type = :credit_vend
      else
        raise "unknown request_type - see request XML"
      end

      meter_number = xml.gsub("\n", '').scan(/msno=\"([0-9]*)\"/).flatten.first
      amount_rec = xml.scan(/amt value="([0-9.]+)" symbol="([A-Z]+)"/).first
      msg_id_rec = xml.scan(/msgID dateTime="([A-Z 0-9.]+)" uniqueNumber="([0-9]+)"/).first
      created_at = msg_id_rec[0]
      request_id = msg_id_rec[1]

      if req_type == :credit_vend
        amount = amount_rec[0]
        currency = amount_rec[1]

        if TEST_METER_NUMBERS.include?(meter_number)
          if amount == '210.00'
            credit_vend_multiple_tariffs_success_xml meter_number, amount, currency, created_at, request_id
          else
            credit_vend_success_xml meter_number, amount, currency, created_at, request_id
          end
        else
          credit_vend_fail_xml1 meter_number, amount, currency, created_at, request_id
        end
      elsif req_type == :last_advice
        last_advice_last_advice_xml
      else
        raise "unknown request_type - see request XML"
      end
    end


    private

    def credit_vend_multiple_tariffs_success_xml meter_number, amount, currency, created_at, request_id
      invoice_number = (rand(10**7)).to_s.ljust(7, "0")
      tariff_rate = rand(0.5...0.8).round(2)
      electricity = ( amount.to_f / tariff_rate ).round

      <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><creditVendResp xmlns="http://www.nrs.eskom.co.za/xmlvend/revenue/2.1/schema"><clientID xsi:type="EANDeviceID" ean="VUPSB" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><serverID xsi:type="GenericDeviceID" id="1" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><terminalID xsi:type="EANDeviceID" ean="0000000000002" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><reqMsgID dateTime="20171217092021" uniqueNumber="33011" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><respDateTime xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">2017-12-17T09:19:49.6529751-04:00</respDateTime><dispHeader xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">Credit Purchase</dispHeader><operatorMsg xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">Credit Purchase successful</operatorMsg><custMsg xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">Credit Purchase</custMsg><clientStatus xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema"><availCredit value="999420.00" symbol="XCG" /><batchStatus banking="open" sales="open" shift="open" /></clientStatus><utility name="Aqualectra" address="Curacao" taxRef="" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><vendor name="Conlog" address="Curacao" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><custVendDetail name="JULIANA SIGNALD  A" address="SABANA BAKA 25 A WILLEMSTAD" accNo="11179600" locRef="1513520" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><creditVendReceipt receiptNo="VUPSB/3994500"><transactions><tx xsi:type="CreditVendTx" receiptNo="VUPSB/3994500"><amt value="22.00" /><creditTokenIssue xmlns:q1="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" xsi:type="q1:SaleCredTokenIssue"><q1:desc>Credit Token</q1:desc><q1:meterDetail msno="04155183447" sgc="300601" krn="1" ti="1"><q1:meterType tt="02" /></q1:meterDetail><q1:token xsi:type="q1:STS1Token"><q1:stsCipher>32678132995057592063</q1:stsCipher></q1:token><q1:units value="36.3" siUnit="KWh" /><q1:resource xsi:type="q1:Electricity" /></creditTokenIssue><tariff><name xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">DOMESTICO</name></tariff><tariffBreakdown xmlns:q2="http://www.conlog.co.za/xmlvend/base-ext/2.1.1/schema" xsi:type="q2:StepTariffBreakdown"><q2:steps><q2:Step><q2:units value="28.3" siUnit="KWh" /><q2:rate value="0.60" symbol="XCG" /></q2:Step><q2:Step><q2:units value="8" siUnit="KWh" /><q2:rate value="0.64" symbol="XCG" /></q2:Step></q2:steps></tariffBreakdown></tx><tenderAmt value="22.00" /><change value="0.00" /></transactions></creditVendReceipt></creditVendResp></soap:Body></soap:Envelope>
      XML
    end

    def credit_vend_success_xml meter_number, amount, currency, created_at, request_id
      invoice_number = (rand(10**7)).to_s.ljust(7, "0")
      tariff_rate = rand(0.5...0.8).round(2)
      electricity = ( amount.to_f / tariff_rate ).round

      <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><creditVendResp xmlns="http://www.nrs.eskom.co.za/xmlvend/revenue/2.1/schema"><clientID xsi:type="EANDeviceID" ean="VUPSB" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><serverID xsi:type="GenericDeviceID" id="1" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><terminalID xsi:type="EANDeviceID" ean="0000000000002" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><reqMsgID dateTime="#{created_at}" uniqueNumber="#{request_id}" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><respDateTime xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">2016-09-01T02:05:36.1435546-04:00</respDateTime><dispHeader xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">Credit Purchase</dispHeader><operatorMsg xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">Credit Purchase successful</operatorMsg><custMsg xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">Credit Purchase</custMsg><clientStatus xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema"><availCredit value="997413.57" symbol="XCG" /><batchStatus banking="open" sales="open" shift="open" /></clientStatus><utility name="Aqualectra" address="Curacao" taxRef="" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><vendor name="Conlog" address="Curacao" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><custVendDetail name="CU 3, T" address="" accNo="93000" locRef="101008" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><creditVendReceipt receiptNo="VUPSB/#{invoice_number}"><transactions><tx xsi:type="CreditVendTx" receiptNo="VUPSB/#{invoice_number}"><amt value="#{amount}" /><creditTokenIssue xmlns:q1="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" xsi:type="q1:SaleCredTokenIssue"><q1:desc>Credit Token</q1:desc><q1:meterDetail msno="#{meter_number}" sgc="300601" krn="1" ti="1"><q1:meterType tt="02" /></q1:meterDetail><q1:token xsi:type="q1:STS1Token"><q1:stsCipher>01234567890123456789</q1:stsCipher></q1:token><q1:units value="#{electricity}" siUnit="KWh" /><q1:resource xsi:type="q1:Electricity" /></creditTokenIssue><tariff><name xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">DOMESTICO</name></tariff><tariffBreakdown xmlns:q2="http://www.conlog.co.za/xmlvend/base-ext/2.1.1/schema" xsi:type="q2:StepTariffBreakdown"><q2:steps><q2:Step><q2:units value="#{electricity}" siUnit="KWh" /><q2:rate value="#{tariff_rate}" symbol="#{currency}" /></q2:Step></q2:steps></tariffBreakdown></tx><tenderAmt value="#{amount}" symbol="#{currency}" /><change value="0.00" /></transactions></creditVendReceipt></creditVendResp></soap:Body></soap:Envelope>
      XML
    end

    # test credit-vend request for the last advice flow
    def last_advice_credit_vend_xml
      <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><creditVendResp xmlns="http://www.nrs.eskom.co.za/xmlvend/revenue/2.1/schema"><clientID xsi:type="EANDeviceID" ean="VUPSB" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><serverID xsi:type="GenericDeviceID" id="1" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><terminalID xsi:type="EANDeviceID" ean="0000000000002" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><reqMsgID dateTime="20210723113526" uniqueNumber="968167" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><respDateTime xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">2021-07-23T05:35:30.6819918-04:00</respDateTime><dispHeader xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">Credit Purchase</dispHeader><operatorMsg xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">Credit Purchase Successful</operatorMsg><custMsg xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">Credit Purchase</custMsg><utility name="slice" address="Durban" taxRef="0" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><clientStatus xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema"><availCredit value="0" symbol="XCG" /><batchStatus banking="open" sales="open" shift="open" /></clientStatus><vendor xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><custVendDetail name="     " address="Physical, DEIN 21-15 C, WILLEMSTAD" contactNo="" accNo="3201015109" locRef="4101168723" utilityType="Electricity" daysLastPurchase="0" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><creditVendReceipt receiptNo="4879019"><transactions><tx xsi:type="CreditVendTx" receiptNo="4879019"><amt value="10" symbol="XCG" /><creditTokenIssue xmlns:q1="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" xsi:type="q1:SaleCredTokenIssue"><q1:desc>Credit Token</q1:desc><q1:meterDetail krn="1" ti="1" sgc="300601" unitOfMeasurement="kWh" msno="04257670465"><q1:meterType tt="02" /></q1:meterDetail><q1:token xsi:type="q1:STS1Token"><q1:stsCipher>01234567890123456789</q1:stsCipher></q1:token><q1:units value="15.4" siUnit="kWh" /><q1:resource xsi:type="q1:Electricity" /></creditTokenIssue><tariff><name xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">DOMESTIC ELECTRICITY</name><desc xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">DOMESTIC ELECTRICITY</desc></tariff><tariffBreakdown xmlns:q2="http://www.conlog.co.za/xmlvend/base-ext/2.1.1/schema" xsi:type="q2:StepTariffBreakdown"><q2:steps><q2:Step><q2:units value="0" siUnit="kWh" /><q2:rate value="0.54700" symbol="XCG" /></q2:Step><q2:Step><q2:units value="15.4" siUnit="kWh" /><q2:rate value="0.65330" symbol="XCG" /></q2:Step><q2:Step><q2:units value="0" siUnit="kWh" /><q2:rate value="0.69750" symbol="XCG" /></q2:Step></q2:steps></tariffBreakdown></tx><tx xsi:type="ServiceChrgTx"><amt value="0" symbol="XCG" /><accDesc>VAT</accDesc></tx><tenderAmt value="10.00" symbol="XCG" /><change value="0.00" symbol="XCG" /></transactions><MonthlyTotals xsi:nil="true" /></creditVendReceipt></creditVendResp></soap:Body></soap:Envelope>
      XML
    end

    # test last-advice request for the last advice flow
    def last_advice_last_advice_xml
      <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><adviceResp xsi:type="LastRespAdviceResp" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema"><clientID xsi:type="EANDeviceID" ean="VUPSB" /><serverID xsi:type="GenericDeviceID" id="1" /><terminalID xsi:type="EANDeviceID" ean="0000000000002" /><reqMsgID dateTime="20210723113535" uniqueNumber="379970" /><respDateTime>2021-07-23T05:35:35.3515851-04:00</respDateTime><dispHeader>Last Response Advice</dispHeader><operatorMsg>Last Response Advice</operatorMsg><custMsg /><adviceReqMsgID dateTime="20210723113526" uniqueNumber="968167" /><lastResponse xmlns:q1="http://www.nrs.eskom.co.za/xmlvend/revenue/2.1/schema" xsi:type="q1:CreditVendResp"><clientID xsi:type="EANDeviceID" ean="VUPSB" /><serverID xsi:type="GenericDeviceID" id="1" /><terminalID xsi:type="EANDeviceID" ean="0000000000002" /><reqMsgID dateTime="20210723113526" uniqueNumber="968167" /><respDateTime>2021-07-23T05:35:30.6819918-04:00</respDateTime><dispHeader>Credit Purchase</dispHeader><operatorMsg>Credit Purchase Successful</operatorMsg><custMsg>Credit Purchase</custMsg><utility name="slice" address="Durban" taxRef="0" /><clientStatus><availCredit value="0" symbol="XCG" /><batchStatus banking="open" sales="open" shift="open" /></clientStatus><vendor /><custVendDetail name="     " address="Physical, DEIN 21-15 C, WILLEMSTAD" contactNo="" accNo="3201015109" locRef="4101168723" utilityType="Electricity" daysLastPurchase="0" /><q1:creditVendReceipt receiptNo="4879019"><q1:transactions><q1:tx xsi:type="q1:CreditVendTx" receiptNo="4879019"><q1:amt value="10" symbol="XCG" /><q1:creditTokenIssue xsi:type="SaleCredTokenIssue"><desc>Credit Token</desc><meterDetail krn="1" ti="1" sgc="300601" unitOfMeasurement="kWh" msno="04257670465"><meterType tt="02" /></meterDetail><token xsi:type="STS1Token"><stsCipher>01234567890123456789</stsCipher></token><units value="15.4" siUnit="kWh" /><resource xsi:type="Electricity" /></q1:creditTokenIssue><q1:tariff><name>DOMESTIC ELECTRICITY</name><desc>DOMESTIC ELECTRICITY</desc></q1:tariff><q1:tariffBreakdown xmlns:q2="http://www.conlog.co.za/xmlvend/base-ext/2.1.1/schema" xsi:type="q2:StepTariffBreakdown"><q2:steps><q2:Step><q2:units value="0" siUnit="kWh" /><q2:rate value="0.54700" symbol="XCG" /></q2:Step><q2:Step><q2:units value="15.4" siUnit="kWh" /><q2:rate value="0.65330" symbol="XCG" /></q2:Step><q2:Step><q2:units value="0" siUnit="kWh" /><q2:rate value="0.69750" symbol="XCG" /></q2:Step></q2:steps></q1:tariffBreakdown></q1:tx><q1:tx xsi:type="q1:ServiceChrgTx"><q1:amt value="0" symbol="XCG" /><q1:accDesc>VAT</q1:accDesc></q1:tx><q1:tenderAmt value="10.00" symbol="XCG" /><q1:change value="0.00" symbol="XCG" /></q1:transactions><q1:MonthlyTotals xsi:nil="true" /></q1:creditVendReceipt></lastResponse></adviceResp></soap:Body></soap:Envelope>
      XML
    end

    def credit_vend_fail_xml1 meter_number, amount, currency, created_at, request_id
      <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><soap:Fault><faultcode>soap:Server</faultcode><faultstring>Soap Exception From Server</faultstring><faultactor>url</faultactor><detail><XMLVendFaultResp xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><clientID xsi:type="EANDeviceID" ean="VUPSB" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><terminalID xsi:type="EANDeviceID" ean="0000000000002" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><reqMsgID dateTime="#{created_at}" uniqueNumber="#{request_id}" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema" /><respDateTime xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">2016-09-01T02:31:31.9658203-04:00</respDateTime><dispHeader xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">Vending Server Cluster Error</dispHeader><operatorMsg xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema">There was a fault at the server processing the request</operatorMsg><fault xsi:type="SystemEx" xmlns="http://www.nrs.eskom.co.za/xmlvend/base/2.1/schema"><desc>Meter Not Found</desc></fault></XMLVendFaultResp></detail></soap:Fault></soap:Body></soap:Envelope>
      XML
    end

  end

end

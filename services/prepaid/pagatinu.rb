module PrepaidService
  module Pagatinu

    def self.fetch(operator_code, account_terminal_id, currency, pos_request)
      # valid response
      # :status=>"approved", :message=>"Credit Purchase successful",
      # :receipt_no=>"VUPSB/9915402", :token=>"01234567890123456789",
      # :units=>"217 KWh", :resource=>"electricity", :cust_vend_acct=>"93000",
      # :cust_vend_name=>"CU 3, T", :meter_number=>"04229889888",
      # :tariff_rate_amount=>"0.57", :tariff_rate_currency=>"ANG", :tariff_name=>"DOMESTICO"

      begin
        pagatinu_client = WebPay.opts[:pagatinu_client].new

        request_id = (account_terminal_id.to_s.rjust(6, "0")[-6..-1] +
          pos_request.systan.to_s.rjust(4, "0")[-4..-1]).to_i

        request = {
          meter_no: pos_request.customer_number, amount: pos_request.amount, currency: currency,
          request_id: request_id, created_at: pos_request.client_datetime
        }

        # set advice flag if account is marked in cache
        advice_flag_key_name = "#{pos_request.customer_number}_advice_flag"
        pos_request.repeat = true if MemoryStore.get(advice_flag_key_name)

        # call pagatinu api
        if pos_request.repeat
          resp = pagatinu_client.last_advice_request request
        else
          resp = pagatinu_client.credit_vend_request request
        end

      rescue Faraday::TimeoutError
        MemoryStore.set(advice_flag_key_name, true, 24*60*60) # cache advice flag for 1 day
        return { error: {customer_number: ["Response timeout for #{self}"]}}
      rescue => error
        puts "PAGATINU ERROR: #{error.class}: #{error.message}"
        puts error.backtrace.take(5).join("\n")
        return { error: {customer_number: ['There was an error processing your request, please try later']}}
      end

      if resp[:status] == 'approved'
        info = {}

        # map better key names
        human_mapper = {receipt_no:     'Receipt number',
                        cust_vend_acct: 'Account',
                        cust_vend_name: 'Name',
                        meter_number:   'Meter',
                        tariff_name:    'Tariff'}

        # echo values
        info[human_mapper[:receipt_no]]     = resp[:receipt_no]
        info[human_mapper[:cust_vend_acct]] = resp[:cust_vend_acct]
        info[human_mapper[:cust_vend_name]] = resp[:cust_vend_name]
        info[human_mapper[:meter_number]]   = resp[:meter_number]
        info[human_mapper[:tariff_name]]    = resp[:tariff_name]

        # process values
        info['Cost'] = "#{currency}#{pos_request.amount/100.0}"
        if resp[:resource] == 'electricity'
          info['Energy'] = resp[:units]
          info['Info']   = resp[:tariff_rates].map do |tariff_rate|
            "#{tariff_rate[:units]} @ #{tariff_rate[:currency]}#{tariff_rate[:amount]} p#{tariff_rate[:si_unit]}"
          end.
            join(" / ")
        elsif resp[:resource] == 'water'
          info['Energy'] = resp[:units]
          info['Info']   = resp[:tariff_rates].map do |tariff_rate|
            "#{tariff_rate[:units]} @ #{tariff_rate[:currency]}#{tariff_rate[:amount]} p#{tariff_rate[:si_unit]}"
          end.
            join(" / ")

        else
          raise "unknown resource: #{resp[:resource]}"

        end

        # print out advice flag and remove it from cache
        if pos_request.repeat
          info['Advice'] = 'Yes'
          MEMORY_STORE.delete(advice_flag_key_name)
        end

        # info is returned to client, message is saved to db
        {prepaid_code: resp[:token], info: info, message: resp[:units]}
      else
        {error: { customer_number: [resp[:message]]}}
      end
    end

  end
end

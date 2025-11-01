module FiservService

  class MockFiservClient
    def transfer transaction_id, src_account_type, src_account_id, dest_account_type, dest_account_id, amount, currency, options = {}

      # simulate networ error
      raise 'error' if amount == 300

      # generate random balances for each account
      rand_balance = Proc.new{"#{rand 100000}.#{rand 100}"}
      balances_part = {'IFX'=> {'MonSvcRs'=> {'GLAppXferAddRs' => {
          'XferFromAcctInfo'=> {'AcctBal' => [{"BalType"=>"Current", "Amt"=>rand_balance.call}, {"BalType"=>"Avail", "Amt"=>rand_balance.call}]},
          'XferToAcctInfo'  => {'AcctBal' => [{"BalType"=>"Current", "Amt"=>rand_balance.call}, {"BalType"=>"Avail", "Amt"=>rand_balance.call}]}}}}}

      # return approved/declined
      {status: amount == 200 ? 'declined' : 'approved', raw_response: balances_part}
    end

    def balance account_type, account_id
      {:status        => "approved",
       :balances      => [{:type=>"current",    :amount=>(rand 100000), :currency=>WebPay.opts[:default_curency]},
                          {:type=>"available",  :amount=>(rand 100000), :currency=>WebPay.opts[:default_curency]}],
       :raw_response  => {"IFX" => {}}}
    end
  end

  def self.balance bank_account
    account_type = 'DD' if bank_account.type == 'current'
    account_type = 'SV' if bank_account.type == 'savings'

    begin
      # ARGS: account_type, account_id
      resp =  WebPay.opts[:fiserv_client].new.balance(account_type, bank_account.account_number)

      if resp[:status] == 'approved'
        # resp[:balances] ==> [{:type=>"current", :amount=>97400, :currency=>"USD"}, {:type=>"available", :amount=>97400, :currency=>"USD"}]
        balance = resp[:balances].reduce({}){|a, b| a = b if b[:type] == 'available'}

        return resp.merge(balance: balance) # {:type=>"available", :amount=>97400, :currency=>"USD"}
      else
        return resp
      end
    rescue
      return { error: { amount: ['no response from host'] }}
    end
  end

  def self.transfer type, source_account, target_account, amount, currency, opts = {}

    # wallet to bank - target_account is a bank account to credit
    if type == :wallet_to_bank

      # src account is fixed in fiserv host
      src_account_type = WebPay.opts[:fiserv_wallet_account_type]
      src_account_id = WebPay.opts[:fiserv_wallet_account_id]

      # dest account is credited from wallet
      dest_account_type = 'DD' if target_account.type == 'current'
      dest_account_type = 'SV' if target_account.type == 'savings'
      dest_account_id = target_account.account_number

      # amount
      amount = amount
      currency = currency
      opts = {}
    end

    # bank to wallet - source_account is a bank account to debit
    if type == :bank_to_wallet
      # src account is debited from wallet
      src_account_type = 'DD' if source_account.type == 'current'
      src_account_type = 'SV' if source_account.type == 'savings'
      src_account_id = source_account.account_number

      # dest account is fixed in fiserv host
      dest_account_type = WebPay.opts[:fiserv_wallet_account_type]
      dest_account_id = WebPay.opts[:fiserv_wallet_account_id]

      # amount
      amount = amount
      currency = currency
      opts = {}
    end

    # bank to bank
    if type == :bank_to_bank

      # src account
      src_account_type = 'DD' if source_account.type == 'current'
      src_account_type = 'SV' if source_account.type == 'savings'
      src_account_id = source_account.account_number

      # dest account is fixed in fiserv host
      dest_account_type = 'DD' if target_account.type == 'current'
      dest_account_type = 'SV' if target_account.type == 'savings'
      dest_account_id = target_account.account_number

      # amount
      amount = amount
      currency = currency
      opts = {}
    end

    begin
      # ARGS: transaction_id, src_account_type, src_account_id, dest_account_type, dest_account_id, amount, currency, options = {}
      # EXAMPLE: rand(10**12), 'DD', '9900003588', 'DD', '9900003589', 1, 'USD'
      transaction_id = rand(10**12)
      resp =  WebPay.opts[:fiserv_client].new.transfer( transaction_id,
                                                        src_account_type, src_account_id,
                                                        dest_account_type, dest_account_id,
                                                        amount, currency, opts)

      if resp[:status] == 'approved'
        # resp.dig('IFX', 'MonSvcRs', 'GLAppXferAddRs', 'XferToAcctInfo', 'AcctBal')
        # [{"BalType"=>"Current", "Amt"=>"1027.00"}, "BalType"=>"Avail", "Amt"=>"1027.00"}]
        src_account_balance = resp[:raw_response].dig('IFX', 'MonSvcRs', 'GLAppXferAddRs', 'XferFromAcctInfo', 'AcctBal').
          reduce(''){|a, b| a = b['Amt'] if b['BalType'] == 'Avail'}.gsub('.', '').to_i

        dest_account_balance = resp[:raw_response].dig('IFX', 'MonSvcRs', 'GLAppXferAddRs', 'XferToAcctInfo', 'AcctBal').
          reduce(''){|a, b| a = b['Amt'] if b['BalType'] == 'Avail'}.gsub('.', '').to_i

        return resp.merge(src_account_id: {balance: src_account_balance}, dest_account_id: {balance: dest_account_balance})

      else
        return resp
      end
    rescue
      return { error: 'no response from host' }
    end
  end

end

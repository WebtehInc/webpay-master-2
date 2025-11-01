class BankBalanceInquiry < DStruct::DStruct

  attributes  strings: [:account_id]

  def self.call(context)

    user = User[context.user_id]
    balance_inquiry = new(context.params)

    # models
    bank_account = user.accounts_dataset.where(id: balance_inquiry.account_id, type: BANK_ACCOUNT_TYPES.keys.stringify).first

    validation_schema = Dry::Validation.Schema do
      configure do
        config.predicates = SchemaPredicates
        config.messages_file = './models/errors.yml'
        option :bank_account, bank_account

        def valid_source_account?(value)
          bank_account
        end
      end

      key(:account_id) { filled? & numeric? & valid_source_account? }
    end

    balance_inquiry.add_validation_schema validation_schema

    if balance_inquiry.valid?

      resp = CoreBankService.balance bank_account
      context.render_error(resp[:error])  if resp[:error]                 # error
      context.render_error(resp)          if resp[:status] == 'declined'  # declined

      currency = resp.dig(:balance, :currency)        # remote currency
      new_bank_balance = resp.dig(:balance, :amount)  # remote balance

      # currency from remote account must match
      context.render_error('Invalid currency.') unless currency == bank_account.currency

      DB.transaction do

        # we must be pesimistic here
        bank_account.lock!

        # debit with zero amount trx
        Transaction.create( account_id: bank_account.id, user_id: user.id,
                            type: 'debit', status: 'approved', transaction_type: 'bank_balance_inquiry',
                            description: "Balance inquiry for account ##{bank_account.account_number}", balance: new_bank_balance,
                            amount: 0, currency: bank_account.currency)

        # update balance with remote balance
        bank_account.update(balance: new_bank_balance)
      end

      context.render_success(balance: new_bank_balance)
    else
      context.render_error(balance_inquiry.errors)
    end

  end

end

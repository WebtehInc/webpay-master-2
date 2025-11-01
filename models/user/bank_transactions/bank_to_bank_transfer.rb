class BankToBankTransfer < DStruct::DStruct

  attributes  strings:  [:currency, :note],
              integers: [:source_account_id, :target_account_id, :amount]

  def self.call(context)

    user = User[context.user_id]
    transfer = new(context.params)

    # models
    source_account = user.accounts_dataset.where(id: transfer.source_account_id, currency: transfer.currency, type: BANK_ACCOUNT_TYPES.keys.stringify).first
    target_account = user.accounts_dataset.where(id: transfer.target_account_id, currency: transfer.currency, type: BANK_ACCOUNT_TYPES.keys.stringify).first

    validation_schema = Dry::Validation.Schema do
      configure do
        config.predicates = SchemaPredicates
        config.messages_file = './models/errors.yml'
        option :source_account, source_account
        option :target_account, target_account

        def valid_source_account?(value)
          source_account && source_account.active
        end

        def valid_target_account?(value)
          target_account && target_account.active && source_account.id != target_account.id
        end

        def available_funds?(value)
          source_account && source_account.balance > value
        end
      end

      key(:source_account_id) { filled? & valid_source_account? }
      key(:target_account_id) { filled? & valid_target_account? }
      key(:amount)            { int? & positive? & available_funds? }
      key(:currency)          { filled? & alpha? }
      key(:note)              { empty? | size?(5..30) }
    end

    transfer.add_validation_schema validation_schema

    if transfer.valid?

      # return resp.merge(src_account_id: {balance: src_account_balance}, dest_account_id: {balance: dest_account_balance})
      resp = CoreBankService.transfer :bank_to_bank, source_account, target_account, transfer.amount, transfer.currency

      context.render_error({amount: [resp[:error]]})            if resp[:error] # error
      context.render_error({amount: ['declined']}.merge(resp))  if resp[:status] == 'declined'  # declined

      DB.transaction do

        # we must be pesimistic here
        source_account.lock!
        target_account.lock!

        # do NOT update balance for remote accounts with transfer amount
        # new_source_balance = source_account.balance - transfer.amount
        # new_target_balance = target_account.balance + transfer.amount

        # new remote balances
        new_source_balance = resp.dig(:src_account_id, :balance)
        new_target_balance = resp.dig(:dest_account_id, :balance)

        # debit source bank account
        debit = Transaction.create(account_id: source_account.id, user_id: user.id,
                            type: 'debit', status: 'approved', transaction_type: 'transfer_bank_to_bank',
                            description: "To ##{target_account.account_number}", balance: new_source_balance,
                            amount: transfer.amount, currency: transfer.currency, note: transfer.note)
        source_account.update(balance: new_source_balance)

        # credit target bank account
        credit = Transaction.create(account_id: target_account.id, user_id: user.id,
                            type: 'credit', status: 'approved', transaction_type: 'transfer_bank_to_bank',
                            description: "From ##{source_account.account_number}", balance: new_target_balance,
                            amount: transfer.amount, currency: transfer.currency, note: transfer.note, parent_id: debit.id)
        target_account.update(balance: new_target_balance)
      end

      context.render_success()
    else
      context.render_error(transfer.errors)
    end

  end

end

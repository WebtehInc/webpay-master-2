class WalletToBankTransfer < DStruct::DStruct

  attributes  strings:  [:currency, :note],
              integers: [:amount, :source_account_id, :target_account_id]

  def self.call(context)

    user = User[context.user_id]
    transfer = new(context.params)

    # models
    wallet_account = user.accounts_dataset.where(id: transfer.source_account_id, currency: transfer.currency, type: WALLET_ACCOUNT_TYPES.keys.stringify).first
    bank_account = user.accounts_dataset.where(id: transfer.target_account_id, currency: transfer.currency, type: BANK_ACCOUNT_TYPES.keys.stringify).first

    validation_schema = Dry::Validation.Schema do
      configure do
        config.predicates = SchemaPredicates
        config.messages_file = './models/errors.yml'
        option :wallet_account, wallet_account
        option :bank_account, bank_account

        def valid_source_account?(value)
          wallet_account && wallet_account.active
        end

        def valid_target_account?(value)
          bank_account && bank_account.active && wallet_account && wallet_account.id != bank_account.id
        end

        def available_funds?(value)
          wallet_account && wallet_account.balance > value
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

      resp = CoreBankService.transfer :wallet_to_bank, wallet_account, bank_account, transfer.amount, transfer.currency

      context.render_error({amount: [resp[:error]]})            if resp[:error] # error
      context.render_error({amount: ['declined']}.merge(resp))  if resp[:status] == 'declined'  # declined

      DB.transaction do

        # we must be pesimistic here
        wallet_account.lock!
        bank_account.lock!

        new_wallet_balance = wallet_account.balance - transfer.amount
        new_bank_balance = resp.dig(:dest_account_id, :balance) # remote balance

        # debit wallet account
        debit = Transaction.create(account_id: wallet_account.id, user_id: user.id,
                            type: 'debit', status: 'approved', transaction_type: 'transfer_wallet_to_bank',
                            description: "To ##{bank_account.account_number}", balance: new_wallet_balance,
                            amount: transfer.amount, currency: transfer.currency, note: transfer.note)
        wallet_account.update(balance: Sequel.-(:balance, transfer.amount))

        # credit bank account
        credit = Transaction.create(account_id: bank_account.id, user_id: user.id,
                            type: 'credit', status: 'approved', transaction_type: 'transfer_wallet_to_bank',
                            description: "From ##{wallet_account.account_number}", balance: new_bank_balance,
                            amount: transfer.amount, currency: transfer.currency, note: transfer.note, parent_id: debit.id)
        # update balance with remote balance
        bank_account.update(balance: new_bank_balance)
      end

      context.render_success()
    else
      context.render_error(transfer.errors)
    end

  end

end

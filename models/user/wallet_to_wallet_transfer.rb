class WalletToWalletTransfer < DStruct::DStruct

  attributes  strings:  [:target_account_id, :currency, :note],
              integers: [:source_account_id, :amount] # source_account_id is primary key

  def self.call(context)

    user = User[context.user_id]
    transfer = new(context.params)

    # models
    # target_account_id is handler for account_number, not id
    source_account = user.accounts_dataset.where(id: transfer.source_account_id, currency: transfer.currency, type: WALLET_ACCOUNT_TYPES.keys.stringify).first
    target_account = Account.where(account_number: transfer.target_account_id, currency: transfer.currency, type: WALLET_ACCOUNT_TYPES.keys.stringify).first
    target_account_user = target_account&.users&.first

    validation_schema = Dry::Validation.Schema do
      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')

        option :source_account,       source_account
        option :user,                 user
        option :target_account,       target_account
        option :target_account_user,  target_account_user

        # source account limits validation
        source_limit_critria = { account_type: source_account&.type, user_type: user&.type, transaction_type: 'transfer', currency: source_account&.currency, debit_or_credit: 'debit', active: true }
        option :source_user_limits,   Limit.where(source_limit_critria.merge(user_id: user.id)).where{valid_until > Time.now}.to_hash_groups(:type)
        option :source_global_limits, Limit.where(source_limit_critria.merge(user_id: nil)).to_hash_groups(:type)
        option :amount,               transfer.amount
        option :transaction_type,     'transfer'
        include LimitsValidation::SourceAccountLimitsValidation


        # target account limits validation
        target_limit_critria = { account_type: target_account&.type, user_type: target_account_user&.type, transaction_type: 'transfer', currency: target_account&.currency, debit_or_credit: 'credit', active: true }
        option :target_user_limits,             Limit.where(target_limit_critria.merge(user_id: target_account_user&.id)).where{valid_until > Time.now}.to_hash_groups(:type)
        option :target_global_limits,           Limit.where(target_limit_critria.merge(user_id: nil)).to_hash_groups(:type)
        option :target_account_debit_or_credit, 'credit'
        include LimitsValidation::TargetAccountLimitsValidation

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
      key(:target_account_id) { filled? & numeric? & valid_target_account? & target_account_under_count_limit? & target_account_under_volume_limit? }
      # key(:amount)            { int? & positive? & available_funds? }
      key(:amount)            { int? & positive? & available_funds? & under_count_limit? & under_volume_limit? }
      key(:currency)          { filled? & alpha? }
      key(:note)              { size?(5..30) }
    end

    transfer.add_validation_schema validation_schema

    if transfer.valid?
      DB.transaction do

        # we must be pesimistic here
        source_account.lock!
        target_account.lock!

        new_source_balance = source_account.balance - transfer.amount
        new_target_balance = target_account.balance + transfer.amount

        # debit
        debit = Transaction.create(account_id: transfer.source_account_id, user_id: user.id,
                            type: 'debit', status: 'approved', transaction_type: 'transfer',
                            description: "To ##{target_account.account_number}", balance: new_source_balance,
                            amount: transfer.amount, currency: transfer.currency, note: transfer.note)
        source_account.update(balance: Sequel.-(:balance, transfer.amount))

        # credit
        credit = Transaction.create(account_id: target_account[:id], user_id: target_account_user.id,
                            type: 'credit', status: 'approved', transaction_type: 'transfer',
                            description: "From ##{source_account.account_number} by #{user.first_name} #{user.last_name}",
                            balance: new_target_balance,
                            amount: transfer.amount, currency: transfer.currency, note: transfer.note, parent_id: debit.id)
        target_account.update(balance: Sequel.+(:balance, transfer.amount))
      end

      context.render_success
    else
      context.render_error(transfer.errors)
    end

  end
end

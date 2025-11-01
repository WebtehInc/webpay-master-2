class BuyPrepaid < DStruct::DStruct

  attributes strings: [:account_id, :operator_code, :customer_number], integers: [:amount, :systan], booleans: [:repeat],
    times: [:client_datetime]

  def self.call(context)

    user = User[context.user_id]
    buy_prepaid = new(context.params)

    # models
    account  = user.accounts_dataset.where(id: buy_prepaid.account_id, type: WALLET_ACCOUNT_TYPES.keys.stringify).first
    operator = Operator.where(code: buy_prepaid.operator_code, type: 'prepaid').first

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = './models/errors.yml'
        option :account,  account
        option :operator, operator

        # limits validation
        limit_critria = { account_type: account&.type, user_type: user&.type, transaction_type: 'prepaid', currency: account&.currency, debit_or_credit: 'debit', active: true }
        option :user,                 user
        option :source_user_limits,   Limit.where(limit_critria.merge(user_id: user.id)).where{valid_until > Time.now}.to_hash_groups(:type)
        option :source_global_limits, Limit.where(limit_critria.merge(user_id: nil)).to_hash_groups(:type)
        option :source_account,       account
        option :amount,               buy_prepaid.amount
        option :transaction_type,     'prepaid'
        include LimitsValidation::SourceAccountLimitsValidation

        def valid_source_account?(value)
          account
        end

        def available_funds?(value)
          account && account.balance > value
        end

        def valid_operator?(value)
          operator && operator.active
        end

        def over_operator_min_amount?(value)
          operator && operator.min_amount <= value
        end

        def valid_customer?(value)
          true
        end
      end

      key(:account_id)      { filled? & numeric? & valid_source_account? }
      key(:operator_code)   { filled? & valid_operator? }
      key(:customer_number) { filled? & numeric? & valid_customer? }
      key(:amount)          { int? & positive? & available_funds? & over_operator_min_amount? & under_count_limit? & under_volume_limit? }
    end

    buy_prepaid.add_validation_schema validation_schema

    if buy_prepaid.valid?

      # fetch prepaid code
      resp = PrepaidService.fetch(operator.code, account.id, account.currency, buy_prepaid)

      # prepaid error
      context.render_error(resp[:error]) if resp[:error]

      # prepaid ok
      prepaid_code    = resp[:prepaid_code]
      prepaid_info    = resp[:info]
      prepaid_message = resp[:message]

      # api output; also saved to db
      api_output = {'Operator': operator.name, 'Code': prepaid_code.in_groups_by(4)}

      DB.transaction do

        # we must be pessimistic here
        account.lock!

        new_account_balance = account.balance - buy_prepaid.amount

        # debit user
        Transaction.create( account_id: buy_prepaid.account_id, user_id: user.id, operator_code: operator.code,
                            type: 'debit', status: 'approved', transaction_type: 'prepaid', response_message: prepaid_message,
                            description: "#{operator.name}: #{prepaid_info['Energy']}", balance: new_account_balance,
                            amount: buy_prepaid.amount, currency: account.currency, note: api_output.to_desc)

        # debit account
        account.update(balance: Sequel.-(:balance, buy_prepaid.amount))

        # credit operator
        # TODO
      end

      context.render_success(api_output.merge(prepaid_info))
    else
      context.render_error(buy_prepaid.errors)
    end
  end
end

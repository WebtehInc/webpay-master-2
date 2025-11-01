class PayBill < DStruct::DStruct

  attributes strings: [:account_id, :operator_code, :customer_number], integers: [:amount]

  def self.call(context)

    user = User[context.user_id]
    pay_bill = new(context.params)

    # models
    account  = user.accounts_dataset.where(id: pay_bill.account_id, type: WALLET_ACCOUNT_TYPES.keys.stringify).first
    operator = Operator.where(code: pay_bill.operator_code, type: 'bill').first
    customer = Customer.where(operator_code: pay_bill.operator_code, currency: account.try(:currency),
                              number: pay_bill.customer_number).first

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = './models/errors.yml'
        option :account,  account
        option :customer, customer
        option :operator, operator
        option :pay_bill, pay_bill

        # limits validation
        limit_critria = { account_type: account&.type, user_type: user&.type, transaction_type: 'bill', currency: account&.currency, debit_or_credit: 'debit', active: true }
        option :user,                 user
        option :source_user_limits,   Limit.where(limit_critria.merge(user_id: user.id)).where{valid_until > Time.now}.to_hash_groups(:type)
        option :source_global_limits, Limit.where(limit_critria.merge(user_id: nil)).to_hash_groups(:type)
        option :source_account,       account
        option :amount,               pay_bill.amount
        option :transaction_type,     'bill'
        include LimitsValidation::SourceAccountLimitsValidation

        def valid_source_account?(value)
          account
        end

        def available_funds?(value)
          account && account.balance > value
        end

        def valid_customer?(value)
          customer
        end

        def valid_operator?(value)
          operator && operator.active
        end

        def over_operator_min_amount?(value)
          operator && operator.min_amount <= value
        end
      end

      key(:account_id)      { filled? & numeric? & valid_source_account? }
      key(:operator_code)   { filled? & valid_operator? }
      key(:customer_number) { filled? & numeric? & valid_customer? }
      key(:amount)          { int? & positive? & available_funds? & over_operator_min_amount? & under_count_limit? & under_volume_limit? }
    end

    pay_bill.add_validation_schema validation_schema

    if pay_bill.valid?

      # bug or feature?
      #  we got #<Sequel::SQL::NumericExpression:0x007ff2b2d28370> for Sequel.- on balance
      new_account_balance = account.balance - pay_bill.amount
      new_customer_balance = (customer.balance + pay_bill.amount)/100.0

      # api output
      api_output = {'Operator': operator.name, 'Account number': pay_bill.customer_number, 'Balance': "#{new_customer_balance} #{account.currency}"}

      DB.transaction do

        # we must be pesimistic here
        account.lock!
        customer.lock!



        # debit user
        Transaction.create( account_id: pay_bill.account_id, user_id: user.id, operator_code: operator.code,
                            type: 'debit', status: 'approved', transaction_type: 'bill', customer_number: pay_bill.customer_number,
                            description: "#{operator.name}", balance: new_account_balance,
                            amount: pay_bill.amount, currency: account.currency, note: api_output.to_desc)
        account.update(balance: Sequel.-(:balance, pay_bill.amount))

        # adjust customer balance
        customer.update(balance: Sequel.+(:balance, pay_bill.amount))

        # credit operator
        # TODO
      end

      context.render_success(api_output)
    else
      context.render_error(pay_bill.errors)
    end
  end
end

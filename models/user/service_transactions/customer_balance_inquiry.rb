class CustomerBalanceInquiry < DStruct::DStruct

  attributes strings: [:account_id, :operator_code, :customer_number]

  def self.call(context)

    user_id = context.user_id
    balace_inquiry = new(context.params)

    # models
    account  = User[user_id].accounts_dataset.where(id: balace_inquiry.account_id, type: WALLET_ACCOUNT_TYPES.keys.stringify).first
    operator = Operator.where(code: balace_inquiry.operator_code).first
    customer = Customer.where(operator_code: balace_inquiry.operator_code, currency: account.try(:currency),
                              number: balace_inquiry.customer_number).first

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = './models/errors.yml'
        option :account, account
        option :customer, customer
        option :operator, operator

        def valid_source_account?(value)
          account
        end

        def valid_customer?(value)
          customer
        end

        def valid_operator?(value)
          operator
        end
      end

      key(:account_id)      { filled? & numeric? & valid_source_account? }
      key(:operator_code)   { filled? & valid_operator?}
      key(:customer_number) { filled? & valid_customer? }
    end

    balace_inquiry.add_validation_schema validation_schema

    if balace_inquiry.valid?
      context.render_success({balance_info: "Current balance for #{operator.name} is #{customer.balance/100.0} #{account.currency}",
                              customer: customer.values})
    else
      context.render_error(balace_inquiry.errors)
    end
  end
end

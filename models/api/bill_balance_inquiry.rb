require_relative 'common_terminal_validators'

class BillBalanceInquiry < DStruct::DStruct

  attributes  strings: [:access_token, :digest, :operator_code, :customer_number, :currency, :api_version,
                        :application_version, :cashier_pin],
              integers: [:cashier_id]

  def self.call(context)

    input = new(context.params)

    # models
    terminal = Terminal.where(access_token: input.access_token).first
    cashier  = Cashier.where( hashed_pin: Digest::SHA512.hexdigest(input.cashier_pin.to_s), id: input.cashier_id,
                              active: true, terminal_id: terminal.try(:id)).first
    account  = Account.where(id: terminal.try(:account_id)).first
    operator = Operator.where(code: input.operator_code, type: 'bill').first
    customer = Customer.where(operator_code: input.operator_code, currency: input.currency,
                              number: input.customer_number).first

    # validation
    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :terminal, terminal
        option :customer, customer
        option :operator, operator
        option :input, input
        option :account, account
        option :cashier, cashier

        include CommonTerminalValidators

        # def enabled_service?(value)
        #   account && account.flag for thid service
        # end

        def valid_digest?(value)
          terminal && value == Digest::SHA512.hexdigest(
                                  terminal.terminal_key.to_s + terminal.access_token.to_s + input.operator_code.to_s +
                                  input.customer_number.to_s + input.currency.to_s)
        end

        def valid_customer?(value)
          customer
        end

        def valid_currency?(value)
          operator && value == operator.currency
        end
      end

      # echoed
      key(:api_version)         { filled? }
      key(:application_version) { filled? }

      # required
      key(:access_token)        { filled? & valid_terminal? & working_time?}
      key(:digest)              { filled? & valid_digest? }
      key(:operator_code)       { filled? & valid_operator? }
      key(:customer_number)     { filled? & numeric? & valid_customer? }
      key(:currency)            { filled? & valid_currency? }
      key(:cashier_pin)         { filled? & valid_cashier?}
      key(:cashier_id)          { int? }
    end

    input.add_validation_schema validation_schema

    if input.valid?
      digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + input.customer_number.to_s)
      context.render_success  digest:       digest,
                              cashier:      cashier.full_name,
                              balance:      customer.balance,
                              due_date:     customer.due_date,
                              due_balance:  customer.due_balance,
                              currency:     customer.currency,
                              api_version:          input.api_version,
                              application_version:  input.application_version
    else
      context.render_error(input.errors)
    end
  end
end

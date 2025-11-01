class BillPayment < DStruct::DStruct
  attributes strings: [:access_token, :digest, :operator_code, :customer_number, :currency, :api_version, :application_version, :systan, :payment_method, :payment_method_type, :cashier_pin],
             integers: [:amount, :cashier_id],
             times: [:client_datetime]

  def self.call(context)
    input = new(context.params)

    # models
    terminal = Terminal.where(access_token: input.access_token).first
    cashier = Cashier.where(hashed_pin: Utils.digest_SHA512(input.cashier_pin), id: input.cashier_id, active: true, terminal_id: terminal.try(:id)).first
    account = Account.where(id: terminal.try(:account_id)).first
    operator = Operator.where(code: input.operator_code, type: "bill").first
    customer = Customer.where(operator_code: input.operator_code, currency: account.try(:currency), number: input.customer_number).first

    # validation
    validation_schema = Dry::Validation.Form do
      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join("../errors.yml")
        option :terminal, terminal
        option :customer, customer
        option :operator, operator
        option :input, input
        option :account, account
        option :cashier, cashier

        include CommonTerminalValidators

        def enabled_service?(value)
          account && account.bill_payments
        end

        def valid_digest?(value)
          terminal && value == Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, input.operator_code, input.customer_number, input.amount, input.currency, input.systan)
        end

        def over_operator_min_amount?(value)
          operator && operator.min_amount <= value
        end

        def valid_customer?(value)
          customer
        end

        def active_customer?(value)
          customer && customer.active
        end

        def valid_currency?(value)
          operator && value == operator.currency
        end

        def unique?(value)
          terminal && !Transaction.where(terminal_id: terminal.id, systan: value, services_batch_number: terminal.services_batch_number).first
        end
      end

      # echoed
      key(:api_version) { filled? }
      key(:application_version) { filled? }

      # required
      key(:access_token) { filled? & valid_terminal? & enabled_service? & working_time? }
      key(:digest) { filled? & valid_digest? }
      key(:operator_code) { filled? & valid_operator? }
      key(:customer_number) { filled? & numeric? & valid_customer? & active_customer? }
      key(:amount) { int? & over_min_amount? & below_max_amount? & over_operator_min_amount? & under_credit_limit? }
      key(:currency) { filled? & valid_currency? }
      key(:systan) { filled? & unique? }
      key(:client_datetime) { filled? }
      key(:cashier_pin) { filled? & valid_cashier? }
      key(:cashier_id) { int? }
      key(:payment_method) { filled? & inclusion?(ApiHelpers::PAYMENT_METHODS) & valid_payment_method_type? }
      key(:payment_method_type) { empty? | inclusion?(ApiHelpers::PAYMENT_METHOD_TYPES) }
    end

    input.add_validation_schema validation_schema

    if input.valid?
      api_and_app_versions = { api_version: input.api_version, application_version: input.application_version }

      # trx values
      # bug or feature?
      # if we update customer first we got #<Sequel::SQL::NumericExpression:0x007ff2b2d28370> for customer.balance
      new_customer_balance = customer.balance + input.amount
      new_batch_amount = terminal.batch_amount + input.amount
      new_balance = account.balance # + input.amount # we dont use balance but exposure
      # new_exposure_amount = account.exposure_amount + input.amount

      t = nil
      DB.transaction do

        # we must be pesimistic here
        # account.lock!
        customer.lock!
        terminal.lock!

        #### debit merchant
        t = Transaction.create({
          account_id: account.id, terminal_id: terminal.id, systan: input.systan, customer_number: input.customer_number,
          type: "credit", status: "approved", transaction_type: "bill_mpos", operator_code: operator.code,
          description: "Bill payment to #{operator.name}", balance: new_balance, cashier_id: cashier.id,
          note: "Batch balance: #{new_batch_amount / 100.0} #{account.currency}",
          amount: input.amount, currency: account.currency, services_batch_number: terminal.services_batch_number,
          client_datetime: input.client_datetime, payment_method: input.payment_method,
          payment_method_type: input.payment_method_type,
        }.merge(api_and_app_versions))

        # update merchant account
        # account.update(balance: Sequel.+(:balance, input.amount), exposure_amount: Sequel.+(:exposure_amount, input.amount))
        account.update(exposure_amount: Sequel.+(:exposure_amount, input.amount))

        # adjust customer balance
        customer.update(balance: Sequel.+(:balance, input.amount))

        # update terminal batch amount
        terminal.update({ batch_amount: Sequel.+(:batch_amount, input.amount) })
      end

      # build response
      response = { id: t.id,
                   due_date: customer.due_date,
                   due_balance: customer.due_balance,
                   currency: input.currency,
                   digest: Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, t.id),
                   cashier: cashier.full_name }.merge(api_and_app_versions)

      ApiHelpers.cache_response(input, response)
      context.render_success(response)
    else
      context.render_error(input.errors)
    end
  end
end

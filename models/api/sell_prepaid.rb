class SellPrepaid < DStruct::DStruct
  attributes strings: [:access_token, :digest, :operator_code, :customer_number, :currency, :api_version,
                       :application_version, :systan, :payment_method, :payment_method_type, :cashier_pin],
             integers: [:amount, :cashier_id],
             booleans: [:repeat], # optional flag for advice, also set internally from cache flag
             times: [:client_datetime]

  def self.call(context)
    input = new(context.params)

    # models
    terminal = Terminal.where(access_token: input.access_token).first
    cashier = Cashier.where(hashed_pin: Digest::SHA512.hexdigest(input.cashier_pin.to_s), id: input.cashier_id,
                            active: true, terminal_id: terminal.try(:id)).first
    account = Account.where(id: terminal.try(:account_id)).first
    operator = Operator.where(code: input.operator_code, type: "prepaid").first

    # validation
    validation_schema = Dry::Validation.Form do
      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join("../errors.yml")
        option :input, input
        option :terminal, terminal
        option :operator, operator
        option :account, account
        option :cashier, cashier

        include CommonTerminalValidators

        def enabled_service?(value)
          account && account.sell_prepaids
        end

        def valid_digest?(value)
          terminal && value == Digest::SHA512.hexdigest(
            terminal.terminal_key.to_s + terminal.access_token.to_s +
            input.operator_code.to_s + input.customer_number.to_s +
            input.amount.to_s + input.currency.to_s +
            input.systan.to_s
          )
        end

        def over_operator_min_amount?(value)
          operator && operator.min_amount <= value
        end

        def valid_customer?(value)
          true
        end

        def valid_currency?(value)
          operator && value == operator.currency
        end
      end

      # echoed
      key(:api_version) { filled? }
      key(:application_version) { filled? }

      # required
      key(:access_token) { filled? & valid_terminal? & enabled_service? & working_time? }
      key(:digest) { filled? & valid_digest? }
      key(:operator_code) { filled? & valid_operator? }
      key(:customer_number) { filled? & valid_customer? }
      key(:amount) { int? & over_min_amount? & over_operator_min_amount? & below_max_amount? & under_credit_limit? }
      key(:currency) { filled? & valid_currency? }
      key(:systan) { filled? }
      key(:client_datetime) { filled? }
      key(:cashier_pin) { filled? & valid_cashier? }
      key(:cashier_id) { int? }
      key(:payment_method) { filled? & inclusion?(ApiHelpers::PAYMENT_METHODS) & valid_payment_method_type? }
      key(:payment_method_type) { empty? | inclusion?(ApiHelpers::PAYMENT_METHOD_TYPES) }
    end

    input.add_validation_schema validation_schema

    if input.valid?
      # echo versions
      api_and_app_versions = { api_version: input.api_version, application_version: input.application_version }

      # fetch prepaid code
      resp = PrepaidService.fetch(operator.code, terminal.id, account.currency, input)

      # prepaid error
      context.render_error(resp[:error]) if resp[:error]

      # prepaid ok
      prepaid_code = resp[:prepaid_code]
      prepaid_info = resp[:info]
      prepaid_message = resp[:message]

      # trx values
      new_batch_amount = terminal.batch_amount + input.amount
      new_exposure_amount = account.exposure_amount + input.amount
      new_balance = account.balance # constraint on trx table for balance

      t = nil
      DB.transaction do

        # we must be pesimistic here
        terminal.lock!

        #### debit merchant
        t = Transaction.create({
          account_id: account.id, terminal_id: terminal.id, systan: input.systan, customer_number: input.customer_number,
          type: "credit", status: "approved", transaction_type: "prepaid_mpos", operator_code: operator.code,
          description: "#{operator.name} voucher: #{prepaid_code}", balance: new_balance, cashier_id: cashier.id,
          note: "Batch balance: #{new_batch_amount / 100.0} #{account.currency}", response_message: prepaid_message,
          amount: input.amount, currency: account.currency, services_batch_number: terminal.services_batch_number,
          client_datetime: input.client_datetime, payment_method: input.payment_method,
          payment_method_type: input.payment_method_type,
        }.merge(api_and_app_versions))

        # update account
        account.update(exposure_amount: Sequel.+(:exposure_amount, input.amount))

        # update terminal batch amount
        terminal.update({ batch_amount: Sequel.+(:batch_amount, input.amount) })
      end

      # build response
      response = { id: t.id,
                   digest: Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + prepaid_code.to_s),
                   cashier: cashier.full_name,
                   prepaid_code: prepaid_code,
                   info: prepaid_info }.merge(api_and_app_versions)

      ApiHelpers.cache_response(input, response)
      context.render_success(response)
    else
      context.render_error(input.errors)
    end
  end
end

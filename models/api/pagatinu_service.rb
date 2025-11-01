class PagatinuServiceHandler < DStruct::DStruct
  SERVICE_CODE = "pg"

  attributes strings: [:access_token, :digest, :operator_code, :api_version, :application_version, :systan,
                       :payment_method, :payment_method_type, :cashier_pin, :customer_id],
             integers: [:cashier_id, :amount],
             booleans: [:validate_only],
             times: [:client_datetime]

  def self.call(context)
    input = new(context.params)

    terminal = Terminal.where(access_token: input.access_token).first
    cashier = Cashier.where(hashed_pin: Digest::SHA512.hexdigest(input.cashier_pin.to_s), id: input.cashier_id,
                            active: true, terminal_id: terminal.try(:id)).first
    account = Account.where(id: terminal.try(:account_id)).first
    operator = Operator.where(code: SERVICE_CODE, type: "api", active: true).first

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
          account && account.service_pagatinu
        end

        def valid_operator?(value)
          operator
        end

        def over_operator_min_amount?(value)
          operator && operator.min_amount <= value
        end

        def valid_digest?(value)
          terminal && value == Digest::SHA512.hexdigest(
            terminal.terminal_key.to_s + terminal.access_token.to_s + input.customer_id.to_s + input.amount.to_s
          )
        end
      end

      # echoed
      key(:api_version) { filled? }
      key(:application_version) { filled? }

      # general
      key(:access_token) { filled? & valid_terminal? & working_time? & enabled_service? }
      key(:digest) { filled? & valid_digest? }
      key(:systan) { filled? }
      key(:client_datetime) { filled? }
      key(:cashier_pin) { filled? & valid_cashier? }
      key(:cashier_id) { int? }
      key(:payment_method) { filled? & inclusion?(ApiHelpers::PAYMENT_METHODS) & valid_payment_method_type? }
      key(:payment_method_type) { empty? | inclusion?(ApiHelpers::PAYMENT_METHOD_TYPES) }

      # service
      key(:customer_id) { filled? & valid_operator? }
      key(:validate_only) { bool? }
      key(:amount) { int? & over_min_amount? & below_max_amount? & over_operator_min_amount? & under_credit_limit? }
    end

    input.add_validation_schema validation_schema

    if input.valid?
      # echo versions
      api_and_app_versions = { api_version: input.api_version, application_version: input.application_version }

      # call service
      result = PagatinuService.recharge(input.customer_id, SecureRandom.base64(12), input.amount, input.validate_only)

      # api call error
      # { :ok => false, "ErrorCode" => "1006", "ErrorText" => "PaymentTransID already used", "ErrorType" => "Recharge", :error => "Recharge: PaymentTransID already used (1006)" }
      context.render_error(result[:error]) if !result[:ok]

      # api call ok
      recharge = result[:recharge]
      digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token +
                                        recharge["Account"].to_s + recharge["OwnTransID"].to_s)

      # return when ValidateOnly = true
      if input.validate_only
        context.render_success({ digest: digest, data: recharge }.merge(api_and_app_versions))
      end

      # { ok: true, "Account" => "191000", "Delta" => "11000", "PaymentTransID" => "28-11-002", "OwnTransID" => "G20000000307", "Contract.Address" => "Some address" }
      order_summary = "#{operator.name} payment for #{input.customer_id}: Account ##{recharge["Account"]}, Ref ##{recharge["OwnTransID"]}"

      t = nil
      DB.transaction do

        # we must be pesimistic here
        account.lock!
        terminal.lock!

        new_batch_amount = terminal.batch_amount + input.amount
        new_balance = account.balance

        #### debit merchant
        t = Transaction.create({
          account_id: account.id, terminal_id: terminal.id, systan: input.systan,
          type: "credit", status: "approved", transaction_type: "service_mpos", operator_code: operator.code,
          description: order_summary, balance: new_balance, cashier_id: cashier.id,
          note: "Batch balance: #{new_batch_amount / 100.0} #{operator.currency}",
          amount: input.amount, currency: operator.currency, services_batch_number: terminal.services_batch_number,
          client_datetime: input.client_datetime, payment_method: input.payment_method,
          payment_method_type: input.payment_method_type, reference_number: recharge["PaymentTransID"],
          customer_number: input.customer_id, approval_code: recharge["OwnTransID"],
        }.merge(api_and_app_versions))

        # update merchant account
        account.update(exposure_amount: Sequel.+(:exposure_amount, input.amount))

        # update terminal
        terminal.update({ batch_amount: Sequel.+(:batch_amount, input.amount) })
      end

      # build response
      response = { id: t.id,
                   digest: digest,
                   cashier: cashier.full_name,
                   data: recharge }.merge(api_and_app_versions)

      ApiHelpers.cache_response(input, response)
      context.render_success(response)
    else
      context.render_error(input.errors)
    end
  end
end

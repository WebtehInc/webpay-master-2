class TaxServiceHandler
  SERVICE_CODE = "tx"

  def self.get_entities(input)
    terminal = Terminal.where(access_token: input.access_token).first
    cashier = Cashier.where(hashed_pin: Digest::SHA512.hexdigest(input.cashier_pin.to_s), id: input.cashier_id,
                            active: true, terminal_id: terminal.try(:id)).first
    account = Account.where(id: terminal.try(:account_id)).first
    operator = Operator.where(code: SERVICE_CODE, type: "api", active: true).first
    [terminal, cashier, account, operator]
  end

  class ConfirmReference < DStruct::DStruct
    attributes strings: [:access_token, :digest, :operator_code, :api_version,
                         :application_version, :systan, :cashier_pin, :payment_ref],
               integers: [:cashier_id],
               times: [:client_datetime]

    def self.call(context)
      input = new(context.params)
      terminal, cashier, account, operator = TaxServiceHandler.get_entities(input)

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
            # TODO: use flag from account
            # account && account.service_curgas
            true
          end

          def valid_operator?(value)
            operator
          end

          def valid_digest?(value)
            terminal && value == Digest::SHA512.hexdigest(
              terminal.terminal_key.to_s + terminal.access_token.to_s + input.payment_ref.to_s
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

        # service
        key(:payment_ref) { filled? & valid_operator? }
      end

      input.add_validation_schema validation_schema

      if input.valid?
        # echo versions
        api_and_app_versions = { api_version: input.api_version, application_version: input.application_version }

        # call confirm_reference
        platform_id = SecureRandom.uuid()
        result = TaxService.confirm_reference(platform_id, input.client_datetime, input.payment_ref)

        # api call error
        context.render_error(result[:error] || { error: "Service error" }) if !result[:ok]

        # api call ok
        confirm_reference = result[:confirm_reference]

        # build response
        response = { digest: Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + platform_id),
                     cashier: cashier.full_name,
                     data: confirm_reference }.merge(api_and_app_versions)

        context.render_success(response)
      else
        context.render_error(input.errors)
      end
    end
  end

  class Payment < DStruct::DStruct
    attributes strings: [
                 :access_token, :digest, :operator_code, :currency, :api_version, :application_version,
                 :systan, :payment_method, :payment_method_type, :cashier_pin, :platform_id,
               ],
               integers: [:amount, :cashier_id],
               times: [:client_datetime]

    def self.call(context)
      input = new(context.params)
      terminal, cashier, account, operator = TaxServiceHandler.get_entities(input)

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
            account && account.service_curgas
          end

          def valid_operator?(value)
            operator
          end

          def valid_digest?(value)
            terminal && value == Digest::SHA512.hexdigest(
              terminal.terminal_key.to_s + terminal.access_token.to_s +
              input.amount.to_s + input.currency.to_s + input.platform_id.to_s
            )
          end

          def over_operator_min_amount?(value)
            operator && operator.min_amount <= value
          end

          def valid_currency?(value)
            operator && value == operator.currency
          end
        end

        # echoed
        key(:api_version) { filled? }
        key(:application_version) { filled? }

        # general
        key(:access_token) { filled? & valid_terminal? & working_time? & enabled_service? }
        key(:digest) { filled? & valid_digest? }
        key(:amount) { int? & over_min_amount? & over_operator_min_amount? & below_max_amount? & under_credit_limit? }
        key(:currency) { filled? & valid_currency? }
        key(:systan) { filled? }
        key(:client_datetime) { filled? }
        key(:cashier_pin) { filled? & valid_cashier? }
        key(:cashier_id) { int? }
        key(:payment_method) { filled? & inclusion?(ApiHelpers::PAYMENT_METHODS) & valid_payment_method_type? }
        key(:payment_method_type) { empty? | inclusion?(ApiHelpers::PAYMENT_METHOD_TYPES) }

        # service
        key(:platform_id) { filled? & valid_operator? }
      end

      input.add_validation_schema validation_schema

      if input.valid?
        # echo versions
        api_and_app_versions = { api_version: input.api_version, application_version: input.application_version }

        # new payment
        result = TaxService.payment(input.platform_id, input.client_datetime, input.amount)

        # api call error
        context.render_error(result[:error]) if !result[:ok]

        # api call ok
        payment = result[:payment]
        confirm_reference = result[:confirm_reference]
        order_summary = "#{operator.name} payment for #{confirm_reference["customerId"]}/#{confirm_reference["paymentPeriod"]}/#{confirm_reference["taxType"]}: #{payment["paymentRef"]}"

        t = nil
        DB.transaction do

          # we must be pesimistic here
          account.lock!
          terminal.lock!

          amount = input.amount
          new_batch_amount = terminal.batch_amount + amount
          new_balance = account.balance

          #### debit merchant
          t = Transaction.create({
            account_id: account.id, terminal_id: terminal.id, systan: input.systan,
            type: "credit", status: "approved", transaction_type: "service_mpos", operator_code: operator.code,
            description: order_summary, balance: new_balance, cashier_id: cashier.id,
            note: "Batch balance: #{new_batch_amount / 100.0} #{operator.currency}",
            amount: amount, currency: operator.currency, services_batch_number: terminal.services_batch_number,
            client_datetime: input.client_datetime, payment_method: input.payment_method,
            payment_method_type: input.payment_method_type, customer_number: confirm_reference["customerId"],
            reference_number: payment["platformId"], approval_code: payment["paymentId"],
          }.merge(api_and_app_versions))

          # update merchant account
          account.update(exposure_amount: Sequel.+(:exposure_amount, amount))

          # update terminal
          terminal.update({ batch_amount: Sequel.+(:batch_amount, amount) })
        end

        # build response
        response = { id: t.id,
                     digest: Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + payment["paymentId"].to_s),
                     cashier: cashier.full_name,
                     data: payment }.merge(api_and_app_versions)

        ApiHelpers.cache_response(input, response)
        context.render_success(response)
      else
        context.render_error(input.errors)
      end
    end
  end
end

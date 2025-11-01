class CurgasServiceHandler
  SERVICE_CODE = "cg"

  def self.get_entities(input)
    terminal = Terminal.where(access_token: input.access_token).first
    cashier = Cashier.where(hashed_pin: Digest::SHA512.hexdigest(input.cashier_pin.to_s), id: input.cashier_id,
                            active: true, terminal_id: terminal.try(:id)).first
    account = Account.where(id: terminal.try(:account_id)).first
    operator = Operator.where(code: SERVICE_CODE, type: "api", active: true).first
    [terminal, cashier, account, operator]
  end

  class CheckOrder < DStruct::DStruct
    attributes strings: [:access_token, :digest, :operator_code, :api_version,
                         :application_version, :systan, :cashier_pin, :curgas_id],
               integers: [:cashier_id, :quantity, :rush],
               times: [:client_datetime]

    def self.call(context)
      input = new(context.params)
      terminal, cashier, account, operator = CurgasServiceHandler.get_entities(input)

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
              input.curgas_id.to_s + input.quantity.to_s +
              input.rush.to_s
            )
          end

          def valid_quantity?(value)
            value > 0 && value <= 10
          end
        end

        # echoed
        key(:api_version) { filled? }
        key(:application_version) { filled? }

        # general
        key(:access_token) { filled? & valid_terminal? & working_time? } #  enabled_service?
        key(:digest) { filled? & valid_digest? }
        key(:systan) { filled? }
        key(:client_datetime) { filled? }
        key(:cashier_pin) { filled? & valid_cashier? }
        key(:cashier_id) { int? }

        # service
        key(:curgas_id) { filled? & valid_operator? }
        key(:quantity) { int? & valid_quantity? }
        key(:rush) { int? & inclusion?([0, 1]) }
      end

      input.add_validation_schema validation_schema

      if input.valid?
        # echo versions
        api_and_app_versions = { api_version: input.api_version, application_version: input.application_version }

        # fetch prepaid code
        result = CurgasService.check_order(input.curgas_id, input.quantity, input.rush)

        # api call error
        context.render_error(result[:error] || { error: "Service error" }) if !result[:ok]

        # api call ok
        check_order = result[:check_order]

        # build response
        response = { digest: Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + check_order["cods_identity"].to_s),
                     cashier: cashier.full_name,
                     data: check_order }.merge(api_and_app_versions)

        context.render_success(response)
      else
        context.render_error(input.errors)
      end
    end
  end

  class NewOrder < DStruct::DStruct
    attributes strings: [:access_token, :digest, :operator_code, :api_version,
                         :application_version, :systan, :payment_method, :payment_method_type, :cashier_pin, :cods_identity],
               integers: [:cashier_id],
               times: [:client_datetime]

    def self.call(context)
      input = new(context.params)
      terminal, cashier, account, operator = CurgasServiceHandler.get_entities(input)

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
              terminal.terminal_key.to_s + terminal.access_token.to_s + input.cods_identity.to_s
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
        key(:cods_identity) { filled? & valid_operator? }
      end

      input.add_validation_schema validation_schema

      if input.valid?
        # echo versions
        api_and_app_versions = { api_version: input.api_version, application_version: input.application_version }

        # fetch prepaid code
        # { ok: true, new_order: { "cods_identity" => 123, "total_paid" => 8000 } }
        result = CurgasService.new_order(input.cods_identity)

        # api call error
        context.render_error(result[:error]) if !result[:ok]

        # api call ok
        new_order = result[:new_order]
        amount = new_order["total_paid"]
        order_summary = "#{operator.name} payment for #{new_order["curgas_id"]}/#{new_order["quantity_request"]}/#{new_order["rush_delivery"]}: #{new_order["order_num"]}"

        t = nil
        DB.transaction do

          # we must be pesimistic here
          account.lock!
          terminal.lock!

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
            payment_method_type: input.payment_method_type, reference_number: new_order["order_num"],
            customer_number: new_order["curgas_id"], approval_code: new_order["cods_identity"],
          }.merge(api_and_app_versions))

          # update merchant account
          account.update(exposure_amount: Sequel.+(:exposure_amount, amount))

          # update terminal
          terminal.update({ batch_amount: Sequel.+(:batch_amount, amount) })
        end

        # build response
        response = { id: t.id,
                     digest: Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token +
                                                      new_order["cods_identity"].to_s + new_order["total_paid"].to_s),
                     cashier: cashier.full_name,
                     data: new_order }.merge(api_and_app_versions)

        ApiHelpers.cache_response(input, response)
        context.render_success(response)
      else
        context.render_error(input.errors)
      end
    end
  end
end

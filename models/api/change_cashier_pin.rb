class ApiChangeCashierPin < DStruct::DStruct

  attributes  strings:  [:access_token, :digest, :api_version, :application_version, :cashier_pin],
              integers: [:cashier_id, :manager_id]

  def self.call(context)

    update_pin = new(context.params)

    # models
    terminal = Terminal.where(access_token: update_pin.access_token).first
    cashier  = Cashier.where(terminal_id: terminal.try(:id), id: update_pin.cashier_id).first
    manager  = Cashier.where( hashed_pin: Digest::SHA512.hexdigest(update_pin.cashier_pin.to_s),
                              manager: true, active: true, terminal_id: terminal.try(:id),
                              id: update_pin.manager_id).first

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :terminal, terminal
        option :cashier, cashier
        option :manager, manager
        option :update_pin, update_pin

        def valid_terminal?(value)
          terminal && terminal.active
        end

        def valid_digest?(value)
          terminal && value == Digest::SHA512.hexdigest(terminal.terminal_key.to_s + terminal.access_token.to_s + update_pin.cashier_id.to_s)
        end

        def valid_manager?(value)
          manager
        end

        def valid_cashier?(value)
          cashier
        end
      end

      # echoed
      key(:api_version)         { filled? }
      key(:application_version) { filled? }

      # fields
      key(:access_token)  { filled? & valid_terminal? }
      key(:digest)        { filled? & valid_digest? }
      key(:cashier_id)    { int? & valid_cashier?}
      key(:cashier_pin)   { filled? & valid_manager?}
      key(:manager_id)    { int? }
    end

    update_pin.add_validation_schema validation_schema

    if update_pin.valid?
      random_pin = Utils.random_pin(4)

      # update
      Cashier.update(cashier.id, hashed_pin: Digest::SHA512.hexdigest(random_pin))

      # calculate digest
      digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + random_pin)
      context.render_success({api_version: update_pin.api_version,
                              application_version: update_pin.application_version,
                              digest: digest,
                              pin: random_pin})
    else
      context.render_error(update_pin.errors)
    end
  end

end
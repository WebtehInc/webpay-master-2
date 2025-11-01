class ApiUpdateCashier < DStruct::DStruct

  attributes  strings:  [:access_token, :digest, :api_version, :application_version, :cashier_pin],
              booleans: [:manager, :active],
              integers: [:cashier_id, :manager_id]

  def self.call(context)

    update_cashier = new(context.params)

    # models
    terminal = Terminal.where(access_token: update_cashier.access_token).first
    cashier  = Cashier.where(terminal_id: terminal.try(:id), id: update_cashier.cashier_id).first
    manager  = Cashier.where( hashed_pin: Digest::SHA512.hexdigest(update_cashier.cashier_pin.to_s),
                              manager: true, active: true, terminal_id: terminal.try(:id),
                              id: update_cashier.manager_id).first

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :terminal, terminal
        option :cashier, cashier
        option :manager, manager
        option :update_cashier, update_cashier

        def valid_terminal?(value)
          terminal && terminal.active
        end

        def valid_digest?(value)
          terminal && value == Digest::SHA512.hexdigest(terminal.terminal_key.to_s + terminal.access_token.to_s + update_cashier.cashier_id.to_s)
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
      key(:active)        { bool? }
      key(:manager)       { bool? }
      key(:cashier_id)    { int? & valid_cashier?}
      key(:cashier_pin)   { filled? & valid_manager?}
      key(:manager_id)    { int? }
    end

    update_cashier.add_validation_schema validation_schema

    if update_cashier.valid?
      # update
      Cashier.update(cashier.id, manager: update_cashier.manager, active: update_cashier.active)

      # calculate digest
      digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + update_cashier.manager.to_s)
      context.render_success({api_version: update_cashier.api_version,
                              application_version: update_cashier.application_version,
                              digest: digest})
    else
      context.render_error(update_cashier.errors)
    end
  end

end
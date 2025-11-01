class ApiCreateCashier < DStruct::DStruct

  attributes  strings:  [:access_token, :digest, :api_version, :application_version, :full_name, :cashier_pin],
              booleans: [:manager],
              integers: [:manager_id]

  def self.call(context)

    create_cashier = new(context.params)

    # models
    terminal = Terminal.where(access_token: create_cashier.access_token).first
    manager  = Cashier.where( hashed_pin: Digest::SHA512.hexdigest(create_cashier.cashier_pin.to_s),
                              manager: true, active: true, terminal_id: terminal.try(:id),
                              id: create_cashier.manager_id).first

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :terminal, terminal
        option :create_cashier, create_cashier
        option :manager, manager

        def unique?(value)
          terminal && !Cashier.where(terminal_id: terminal.id, full_name: value).first
        end

        def valid_terminal?(value)
          terminal && terminal.active
        end

        def valid_manager?(value)
          manager
        end

        def valid_digest?(value)
          terminal && value == Digest::SHA512.hexdigest(terminal.terminal_key.to_s + terminal.access_token.to_s + create_cashier.full_name.to_s)
        end
      end

      # echoed
      key(:api_version)         { filled? }
      key(:application_version) { filled? }

      # fields
      key(:access_token)  { filled? & valid_terminal? }
      key(:digest)        { filled? & valid_digest? }
      key(:full_name)     { filled? & size?(3..20) & unique? }
      key(:manager)       { bool? }
      key(:cashier_pin)   { filled? & valid_manager?}
      key(:manager_id)    { int? }
    end

    create_cashier.add_validation_schema validation_schema

    if create_cashier.valid?

      random_pin = Utils.random_pin(4)
      # create new one
      c = Cashier.create(terminal_id: terminal.id, full_name: create_cashier.full_name,
                     hashed_pin: Digest::SHA512.hexdigest(random_pin), manager: create_cashier.manager)
      # calculate digest
      digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + random_pin)
      context.render_success({api_version: create_cashier.api_version,
                              application_version: create_cashier.application_version,
                              digest: digest,
                              pin: random_pin,
                              cashier_id: c.id})
    else
      context.render_error(create_cashier.errors)
    end
  end

end

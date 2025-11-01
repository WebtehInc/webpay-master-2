class CheckCashierPin < DStruct::DStruct

  attributes  strings:  [:access_token, :digest, :api_version, :application_version, :cashier_pin],
              integers: [:cashier_id]

  def self.call(context)

    input = new(context.params)

    # models
    terminal = Terminal.where(access_token: input.access_token).first
    account  = Account.where(id: terminal.try(:account_id)).first
    cashier  = Cashier.where( hashed_pin: Digest::SHA512.hexdigest(input.cashier_pin.to_s), id: input.cashier_id,
                              active: true, terminal_id: terminal.try(:id)).first

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :terminal, terminal
        option :account, account
        option :cashier, cashier
        option :input, input

        include CommonTerminalValidators

        def valid_cashier?(value)
          cashier
        end

        def valid_pin?(value)
          cashier
        end

        def valid_digest?(value)
          terminal && value == Digest::SHA512.hexdigest(terminal.terminal_key.to_s + terminal.access_token.to_s + input.cashier_id.to_s)
        end
      end

      # echoed
      key(:api_version)         { filled? }
      key(:application_version) { filled? }

      # fields
      key(:access_token)  { filled? & valid_terminal? & working_time?}
      key(:digest)        { filled? & valid_digest? }
      key(:cashier_id)    { int? }
      key(:cashier_pin)   { filled? & valid_pin? }
    end

    input.add_validation_schema validation_schema

    if input.valid?
      # calculate digest
      digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + input.cashier_pin)
      context.render_success({api_version: input.api_version,
                              application_version: input.application_version,
                              digest: digest})
    else
      context.render_error(input.errors)
    end
  end
end

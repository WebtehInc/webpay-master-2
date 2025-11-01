class CreateCashier < DStruct::DStruct

  attributes  strings:  [:full_name], booleans: [:manager]

  def self.call(terminal_id, context)

    create_cashier = new(context.params)

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        # option :terminal_id, terminal_id
        #
        # def unique?(value)
        #   !Cashier.where(terminal_id: terminal_id, full_name: value).first
        # end
      end

      # key(:full_name) { filled? & size?(3..20) & unique? }
      key(:full_name) { filled? & size?(3..20)}
      key(:manager)   { bool? }
    end

    create_cashier.add_validation_schema validation_schema

    if create_cashier.valid?
      random_pin = Utils.random_pin(4)

      context.render_success({pin: random_pin}) if Cashier.create( terminal_id: terminal_id,
                                                full_name: create_cashier.full_name,
                                                hashed_pin: Digest::SHA512.hexdigest(random_pin),
                                                manager: create_cashier.manager)
    else
      context.render_error(create_cashier.errors)
    end
  end
end
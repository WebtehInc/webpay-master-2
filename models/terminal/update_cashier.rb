class UpdateCashier < DStruct::DStruct

  attributes booleans: [:manager, :active]

  def self.call(cashier_id, context)

    update_cashier = new(context.params)
    update_cashier.add_validation_schema MyValidationSchema

    if update_cashier.valid?
      context.render_success if Cashier.update(cashier_id, context.params, context.user_id)
    else
      context.render_error(update_cashier.errors)
    end
  end

  MyValidationSchema = Dry::Validation.Form do

    configure do
      config.predicates = SchemaPredicates
      config.messages_file = Pathname(__dir__).join('../errors.yml')
    end

    key(:manager)   { bool? }
    key(:active)    { bool? }
  end

end
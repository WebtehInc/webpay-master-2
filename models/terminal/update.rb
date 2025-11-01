class UpdateTerminal < DStruct::DStruct

  attributes  strings:  [ :merchant_name, :merchant_address, :merchant_phone, :merchant_email, :receipt_text]

  def self.call(terminal_id, context)

    update_terminal = new(context.params)
    update_terminal.add_validation_schema MyValidationSchema

    if update_terminal.valid?
      context.render_success if Terminal.update(terminal_id,
                                                update_terminal.to_h.merge(config_version: Sequel.+(:config_version, 1)),
                                                context.user_id)
    else
      context.render_error(update_terminal.errors)
    end
  end

  MyValidationSchema = Dry::Validation.Form do

    configure do
      config.predicates = SchemaPredicates
      config.messages_file = Pathname(__dir__).join('../errors.yml')
    end

    key(:merchant_name)     { filled? & size?(3..20) }
    key(:merchant_address)  { size?(3..30) }
    key(:merchant_phone)    { numeric? & size?(8..15) }
    key(:merchant_email)    { email? & size?(3..20) }
    key(:receipt_text)      { filled? & size?(10..200) }
  end

end
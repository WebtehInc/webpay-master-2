class UpdateProfile < DStruct::DStruct

  attributes strings: [:password, :address, :city, :zip, :country, :phone]

  def self.call(context)
    user_id = context.user_id
    password = context.params[:password]

    input = new(context.params)
    input.add_validation_schema MyValidationSchema
    new_password = password ? {password_hash: BCrypt::Password.create(password)} : {}

    if input.valid?
      context.render_success if User.update(user_id, input.to_h.merge(new_password).except(:password), user_id)
    else
      context.render_error(input.errors)
    end
  end

  MyValidationSchema = Dry::Validation.Form do

    configure do
      config.predicates = SchemaPredicates
      config.messages_file = Pathname(__dir__).join('../errors.yml')
    end

    optional(:password) { filled? & size?(8..15) & strong? }
    key(:address)       { filled? & size?(2..40) }
    key(:city)          { filled? & alpha? & size?(2..20) }
    key(:zip)           { filled? & size?(4..10) }
    key(:country)       { filled? & inclusion?(COUNTRY_CODES) }
    key(:phone)         { filled? & numeric? & size?(8..15) }
  end
end

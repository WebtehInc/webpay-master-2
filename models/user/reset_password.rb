class ResetPassword < DStruct::DStruct

  attributes strings: [:password]

  def self.call(user_id, context)
    password = context.params[:password]

    reset_password = new(password: password)
    reset_password.add_validation_schema MyValidationSchema

    if reset_password.valid?
      User.update_without_audit(user_id, password_hash: BCrypt::Password.create(password), reset_password_token: nil)
    else
      context.render_error(reset_password.errors)
    end
  end

  MyValidationSchema = Dry::Validation.Schema do
    configure do
      config.predicates = SchemaPredicates
      config.messages_file = Pathname(__dir__).join('../errors.yml')
    end
    key(:password) { filled? & size?(8..15) & strong? }
  end

end
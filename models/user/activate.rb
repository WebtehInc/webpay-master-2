class ActivateUser < DStruct::DStruct

  attributes strings: [:token]

  def self.call(context)

    token = context.params[:token]

    activate_user = new(token: token)
    activate_user.add_validation_schema MyValidationSchema

    if activate_user.valid?
      if user = User.find_all_values_by_attrs(activation_token: token)
        User.update_without_audit(user[:id], activation_token: nil, active: true)
        return user
      else
        puts 'Invalid token.'
      end
    else
      puts activate_user.errors
    end
  end

  MyValidationSchema = Dry::Validation.Schema do
    key(:token) do |token|
      token.filled?
    end
  end
end
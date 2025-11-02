class ActivateUser < DStruct::DStruct
  DRIFT = 1*60

  attributes strings: [:token, :otp]

  def self.call(context)

    token = context.params[:token]
    otp = context.params[:otp]

    activate_user = new(token: token, otp: otp)
    activate_user.add_validation_schema MyValidationSchema

    if activate_user.valid?
      if user = User.find_all_values_by_attrs(activation_token: token)
        # Validate OTP code using ROTP
        user_otp_code = user[:otp_code]
        totp = ROTP::TOTP.new(user_otp_code)

        # Verify OTP with drift tolerance
        if totp.verify_with_drift(otp, DRIFT, Time.now)
          puts "=> OTP valid, activating user..."
          User.update_without_audit(user[:id], activation_token: nil, active: true)
          return user
        else
          puts 'Invalid OTP code.'
          context.render_error({otp: ['Invalid OTP code. Please check your authenticator app.']})
          return nil
        end
      else
        puts 'Invalid token.'
        context.render_error({token: ['Invalid activation token.']})
        return nil
      end
    else
      puts activate_user.errors
      context.render_error(activate_user.errors)
      return nil
    end
  end

  MyValidationSchema = Dry::Validation.Schema do
    key(:token) do |token|
      token.filled?
    end

    key(:otp) do |otp|
      otp.filled? & otp.format?(/^\d{6}$/)
    end
  end
end
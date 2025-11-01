class Login < DStruct::DStruct

  attributes strings: [:email, :password]

  def self.call(context)

    email = context.params[:email]
    password = context.params[:password]

    login = new(email: email, password: password)
    login.add_validation_schema MyValidationSchema

    if login.valid?
      if user = User.find_all_values_by_attrs(email: email)

         # do not login inactive users
        if !user.active
          puts msg = "=> inactive user trying to log in ..."
          User.update_without_audit(user[:id], last_login_attempt_at: Time.now)
          context.render_error(message: {title: 'Your account is not active', body: 'Please check your email for the next step'}) and return
        end

        # reset failed_login_count after login inactivity
        if (Time.now > user[:last_login_attempt_at] + WebPay.opts[:failed_login_leeway] rescue nil)
          puts msg = "=> reseting failed login count after inactivity ..."
          User.update_without_audit(user[:id], failed_login_count: 0) # last_login_attempt_at is set bellow
          user[:failed_login_count] = 0
        end

        # block if too many failed logins
        if user[:failed_login_count] > 2
          puts msg = "=> blocking for too many failed logins ..."
          User.update_without_audit(user[:id], failed_login_count: user[:failed_login_count] + 1, last_login_attempt_at: Time.now)
          context.render_forbidden( message: {
                                    title: 'To many failed login attempts',
                                    body: 'Your account is temporarily disabled'})
        end

        # log in
        if (BCrypt::Password.new(user[:password_hash]) == password)
          puts msg = "=> user logged in ..."
          # return {id: user[:id], values: user.to_hash.reject{|k,v| User::NON_PUBLIC_ATTRS.include?(k)}}
          return user
        # or increment failed login
        else
          new_failed_count = user[:failed_login_count] + 1
          puts msg = "=> user failed to log in, incrementing failed login count to #{new_failed_count} ..."
          User.update_without_audit(user[:id], failed_login_count: new_failed_count, last_login_attempt_at: Time.now)
          return false
        end
      else
        puts 'Invalid credentials.'
      end
    else
      puts login.errors
    end
  end

  MyValidationSchema = Dry::Validation.Schema do
    key(:email) do |email|
      email.filled?
    end

    key(:password) do |password|
      password.filled?
    end
  end
end
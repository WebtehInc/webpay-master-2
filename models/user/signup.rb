class Signup < DStruct::DStruct

  attributes  strings: [:first_name, :last_name, :title, :address, :city, :zip, :country, :email, :password, :phone],
              booleans: [:terms],
              dates: [:birth_date]

  def self.call(context)
    password = context.params[:password]
    values = context.params

    signup = new(values)
    signup.add_validation_schema MyValidationSchema

    if signup.valid?

      password_hash = BCrypt::Password.create(password)
      otp_code = Utils.generate_random_token
      activation_token = Utils.generate_random_token

      # reject password and terms from input and merge calculated values
      user = User.signup(signup.to_h.reject {|k,v| [:password, :terms].include?(k)}.
                  merge(password_hash: password_hash, otp_code: otp_code, activation_token: activation_token, settings: USER_SETTINGS))

      # send activation email
      if user
        Mailer.sendmail("/signup/confirm", user)
        context.render_success
      end
    else
      context.render_error(signup.errors)
    end
  end

  MyValidationSchema = Dry::Validation.Form do

    configure do
      config.predicates = SchemaPredicates
      config.messages_file = Pathname(__dir__).join('../errors.yml')

      def unique?(value)
        !User.find_value_by_attrs(:email, email: value)
      end

      def checked?(value)
        value
      end

      def older_than_18?(value)
        Date.today.year - value.year > 17
      end
    end

    key(:password)    { filled? & size?(8..15) & strong? }
    key(:email)       { filled? & email? & unique? }
    key(:terms)       { bool? & checked? }
    key(:birth_date)  { filled? & older_than_18? }

    # profile
    key(:title)       { filled? & inclusion?(%w(mr ms)) }
    key(:first_name)  { filled? & alpha? & size?(2..20) }
    key(:last_name)   { filled? & alpha? & size?(2..20) }
    key(:address)     { filled? & size?(2..40) }
    key(:city)        { filled? & alpha? & size?(2..20) }
    key(:zip)         { empty? | size?(4..10) }
    key(:country)     { filled? & inclusion?(COUNTRY_CODES) }
    key(:phone)       { filled? & numeric? & size?(8..15) }
  end

end
module CurrentEnvironment
  def current_environment!

    self.environment  = :development
    LOGGER.level      = :debug # :debug, :info, :warn, :error, :fatal, :unknown

    # log sql
    # DB.loggers << LOGGER

    # jwt
    WebPay.opts[:jwt_hmac_secret] = ENV["JWT_KEY"]
    WebPay.opts[:jwt_leeway]      = 60 # 60 sec
    WebPay.opts[:jwt_ttl]         = ENV["JWT_TTL"].to_i
    WebPay.opts[:jwt_algorithm]   = 'HS256'

    # token for mobile apps
    WebPay.opts[:mobile_key] = ENV["MOBILE_KEY"]

    # SMTP via Gmail (sanchopansayelburro@gmail.com)
    Mail.defaults do
      delivery_method :smtp,
        address: ENV["WP_SMTP_HOST"],
        port: ENV["WP_SMTP_PORT"],
        user_name: ENV["WP_SMTP_USERNAME"],
        password: ENV["WP_SMTP_PASSWORD"],
        authentication: :plain,
        enable_starttls_auto: true,
        openssl_verify_mode: OpenSSL::SSL::VERIFY_NONE,  # Disable SSL verification for development only
        open_timeout: 10,  # 10 seconds to connect
        read_timeout: 10   # 10 seconds to read response
    end

    # app settings
    WebPay.opts[:app_name] = ENV["APP_NAME"]
    WebPay.opts[:bank_name] = ENV["BANK_NAME"]
    WebPay.opts[:default_curency] = ENV["DEFAULT_CURENCY"]
    WebPay.opts[:failed_login_leeway] = 60 * 5 # 5 min
    WebPay.opts[:otp_ttl] = ENV["OTP_TTL"].to_i

    # document uploads
    WebPay.opts[:upload_path] = './uploads'

    # constants for mailer
    spa_host_url = ENV['WP_SPA_HOST_URL'].sub('/#!', '/#')  # Remove bang from hash for Vue Router
    Mailer.opts[:spa_constants] = { activate_user_path: "#{spa_host_url}/activate",
                                    reset_password_path: "#{spa_host_url}/forgotten-password"}
    Mailer.opts[:error_email] = ENV["ERROR_EMAIL"].to_s.split(',') # send exceptions here


    ########## SERVICES ##########

    # core bank service; i.e. fiserv
    WebPay.opts[:core_bank_service] = ENV['CORE_BANK_SERVICE']

    # ISO switch
    WebPay.opts[:iso_switch_url] = ENV['ISO_SWITCH_URL']
    WebPay.opts[:infoswitch_url] = ENV['INFOSWITCH_URL']
    WebPay.opts[:iso_switch] = InfoSwitch::PosApi

    # crypto service
    WebPay.opts[:crypto_client] = JsecModule::Crypto

    # Pagatinu
    WebPay.opts[:pagatinu_client] = PagafasilImporters::MockPagatinuClient if ENV["PAGATINU_CLIENT"] == 'mock'
    WebPay.opts[:pagatinu_client] = PagafasilImporters::PagatinuClient if ENV["PAGATINU_CLIENT"] == 'live'
    WebPay.opts[:pagatinu_url] = ENV['PAGATINU_URL']

    # Fiserv
    WebPay.opts[:fiserv_client] = FiservService::MockFiservClient if ENV["FISERV_CLIENT"] == 'mock'
    WebPay.opts[:fiserv_client] = PagafasilImporters::FiservClient if ENV["FISERV_CLIENT"] == 'live'
    WebPay.opts[:fiserv_url] = ENV['FISERV_URL']
    WebPay.opts[:fiserv_header_hash] = JSON.parse(File.read('./.env.settings/fiserv_header.json'))
    WebPay.opts[:fiserv_wallet_account_id] = ENV['FISERV_WALLET_ACCOUNT_ID']
    WebPay.opts[:fiserv_wallet_account_type] = ENV['FISERV_WALLET_ACCOUNT_TYPE']
  end
end

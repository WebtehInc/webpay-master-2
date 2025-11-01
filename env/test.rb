module CurrentEnvironment
  def current_environment!

    self.environment  = :test
    LOGGER.level      = :debug # :debug, :info, :warn, :error, :fatal, :unknown

    # log sql
    # DB.loggers << LOGGER

    # jwt
    WebPay.opts[:jwt_hmac_secret] = 'test_key'
    WebPay.opts[:jwt_leeway]      = 60 # 60 sec
    WebPay.opts[:jwt_ttl]         = 600
    WebPay.opts[:jwt_algorithm]   = 'HS256'

    # mail catcher
    Mail.defaults do
      delivery_method :smtp, address: ENV["WP_SMTP_HOST"], port: ENV["WP_SMTP_PORT"]
      delivery_method :test # do not send emails
    end

    # app settings
    WebPay.opts[:app_name] = 'My app'
    WebPay.opts[:bank_name] = 'My Bank'
    WebPay.opts[:default_curency] = 'USD'
    WebPay.opts[:failed_login_leeway] = 60 * 5
    WebPay.opts[:otp_ttl] = 60 * 15

    # document uploads
    WebPay.opts[:upload_path] = './uploads'

    # constants for mailer
    spa_host_url = ENV['WP_SPA_HOST_URL']
    Mailer.opts[:spa_constants] = { activate_user_path: "#{spa_host_url}/activate",
                                    reset_password_path: "#{spa_host_url}/forgotten-password"}
    Mailer.opts[:error_email] = 'damir@webteh.us' # send exceptions here


    ########## SERVICES ##########

    # core bank service; i.e. fiserv
    WebPay.opts[:core_bank_service] = ENV['CORE_BANK_SERVICE']

    # ISO switch
    WebPay.opts[:iso_switch_url] = ENV['ISO_SWITCH_URL']
    WebPay.opts[:infoswitch_url] = ENV['INFOSWITCH_URL']
    WebPay.opts[:iso_switch] = InfoSwitch::PosApi

    # crypto service
    WebPay.opts[:crypto_client] = JsecModule::Crypto

    # pagatinu
    # WebPay.opts[:pagatinu_client] = PagafasilImporters::PagatinuClient
    WebPay.opts[:pagatinu_client] = PagafasilImporters::MockPagatinuClient
    WebPay.opts[:pagatinu_url] = ENV['PAGATINU_URL']

    # Fiserv
    # WebPay.opts[:fiserv_client] = PagafasilImporters::FiservClient
    WebPay.opts[:fiserv_client] = FiservService::MockFiservClient
    WebPay.opts[:fiserv_url] = ENV['FISERV_URL']
    WebPay.opts[:fiserv_header_hash] = JSON.parse(File.read('./.env.settings/fiserv_header.json')) if WebPay.opts[:fiserv_client]
    WebPay.opts[:fiserv_wallet_account_id] = ENV['FISERV_WALLET_ACCOUNT_ID']
    WebPay.opts[:fiserv_wallet_account_type] = ENV['FISERV_WALLET_ACCOUNT_TYPE']
  end
end

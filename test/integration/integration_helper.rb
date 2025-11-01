require "./test/test_helper"
require "rack"
require "rack/test"
require "pp"

APP = Rack::Builder.parse_file("config.ru").first
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/536.5 (KHTML, like Gecko) Chrome/19.0.1084.56 Safari/536.5"

# save typing when checking for these
LIMIT_COUNT_MSG = "number of transactions limit exceeded"
LIMIT_VOLUME_MSG = "transactions volume limit exceeded"
LIMIT_COUNT_MSG_FOR_TARGET_ACCOUNT = "number of transactions limit exceeded for target account"
LIMIT_VOLUME_MSG_FOR_TARGET_ACCOUNT = "transactions volume limit exceeded for target account"

# do not log sql
DB.loggers = []

# load settings
Setting.dataset.delete
puts "  => loading settings from dev.settings.json"
Setting.serializer file_path: "./test/fixtures", file_name: "settings.json", primary_key: :name
Setting.save_to_db_from_file!

# faster signup/login
BCrypt::Engine.cost = 1

# mask_pan form admin
class Card
  def self.mask_pan(pan)
    "#{pan[0...6]}******#{pan[-4..-1]}"
  end
end

class Test < Minitest::Test
  include Rack::Test::Methods

  def app
    APP
  end

  def setup
    # set headers
    header "User-Agent", USER_AGENT
    header "Content-Type", "application/json"
    @user_updatable_attrs = { address: "address", city: "city",
                              zip: "123456", country: "DZ", phone: "12345678" }
    super
  end

  def signup_user(attrs = {})
    params = @user_updatable_attrs.merge(first_name: "pero", last_name: "peric", birth_date: (Date.today - 18 * 366).to_s,
                                         email: "pero@webteh.us", title: "mr", password: "qwe123!Q", terms: true).merge(attrs)
    post "/signup", params.to_json
    user = User.where(email: params[:email]).first
    post "activate-user/#{user.activation_token}", { token: user.activation_token }.to_json
    user
  end

  def login_user(attrs = {})
    post "/login", { email: "pero@webteh.us", password: "qwe123!Q" }.merge(attrs).to_json
    header "Authorization", "Bearer #{JSON.parse(last_response.body)["token"]}"
  end

  def authorize_with_otp(user = nil)
    user = User.first unless user
    totp = ROTP::TOTP.new(user[:otp_code])
    post "/verify-otp", { otp: totp.now }.to_json
  end

  def create_cashier(terminal, attrs = {})
    params = { full_name: "John Cashier", manager: false }.merge(attrs)
    post "/terminals/#{terminal.id}/cashiers/create", params.to_json
    [Cashier.where(full_name: params[:full_name]).first, JSON.parse(last_response.body)["pin"]] # [cashier, pin]
  end

  def sell_voucher(terminal, payment_method = "cash", payment_method_type = "", pin, operator, voucher, cashier_id)
    systan = rand(1234567890)
    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, voucher.name, systan)
    post "/api/sell-voucher", { name: voucher.name, access_token: terminal.access_token, digest: digest, systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                                client_datetime: Time.now.to_s, payment_method: payment_method, payment_method_type: payment_method_type, cashier_pin: pin, cashier_id: cashier_id }.to_json
    assert last_response.ok?
  end

  def pay_bill(terminal, payment_method = "cash", payment_method_type = "", amount = 10000, pin, operator, customer, systan, cashier_id)
    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, operator.code, customer.number, amount, customer.currency, systan)
    post "/api/bill-payment", { operator_code: operator.code, customer_number: customer.number, amount: amount, currency: customer.currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: "1.0.0.", application_version: "1.0.0.", client_datetime: Time.now.to_s, payment_method: payment_method,
                                payment_method_type: payment_method_type, cashier_pin: pin, cashier_id: cashier_id }.to_json
    assert last_response.ok?
  end

  def ok?
    send(verb, path)
    assert last_response.ok?, "should be 200 ok"
  end

  def unauthorized?(verb, path)
    send(verb, path)
    assert last_response.unauthorized?, "should be 401 unauthorized"
  end

  def forbidden?(verb, path)
    send(verb, path)
    assert last_response.forbidden?, "should be 403 forbidden"
  end
end

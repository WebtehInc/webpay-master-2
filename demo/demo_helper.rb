unless ENV['WP_ENV'] == 'development'
  puts; puts "WP_ENV must be set to development"; puts
  exit
end

require "rack/test"
require "minitest/autorun"
require "faker"

APP = Rack::Builder.parse_file('./demo/demo_config.ru').first
USER_AGENT  = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/536.5 (KHTML, like Gecko) Chrome/19.0.1084.56 Safari/536.5'
DB.loggers  = []
CURRENCY    = 'XCG'
PASSWORD    = 'qwe123!Q'
BIN         = '4400'
PAN         = '4400539098448033'
PIN_BLOCK   = '1234'

class Demo < Minitest::Test
  include Rack::Test::Methods

  def app
    APP
  end

  def setup
    # set headers
    header "User-Agent", USER_AGENT
    header "Content-Type", "application/json"
  end

  def signup_user(attrs = {})
    post '/signup', attrs.to_json
    user = User.where(email: attrs[:email]).first
    # activation_token = user.activation_token
    # post "activate-user/#{user.activation_token}", {token: user.activation_token}.to_json
    user.update activation_token: nil, active: true if user
  end

  def login_user(user)
    post '/login', {email: user[:email], password: PASSWORD}.to_json
    header "Authorization", "Bearer #{JSON.parse(last_response.body)['token']}" rescue nil
  end

  def authorize_with_otp(user)
    totp = ROTP::TOTP.new(user[:otp_code])
    post '/verify-otp', {otp: totp.now}.to_json
  end
end

require_relative "../integration_helper"

class TestSignupAndLogin < Test

  def test_failed_signup
    post '/signup'
    assert last_response.unprocessable?
    assert_equal 12, JSON.parse(last_response.body).keys.size # 12 errors
  end

  def test_successful_signup

    # registration form
    post '/signup', {title: "mr", first_name: "pero", last_name: "peric", phone: "12345678",
                    email: "pero@webteh.us", password: "qwe123!Q", country: "DZ", address: "address",
                    city: "city", zip: "12345", terms:true, birth_date: "1990-03-22"}.to_json
    assert last_response.ok?
    assert_equal 1, User.count
    assert_equal 0, Account.count # no account before activation

    # user is not active
    user = User.first
    assert_equal false, user.active

    # decline login
    post '/login', {email: "pero@webteh.us",  password: "qwe123!Q"}.to_json
    assert last_response.unprocessable?
    assert_equal 'Your account is not active', JSON.parse(last_response.body)['message']['title']

    # activation page
    get "activate-user/#{user.activation_token}"
    assert last_response.ok?
    assert_equal 3, JSON.parse(last_response.body).keys.size # returns 3 keys - email, first_name, last_name

    # activation form
    post "activate-user/#{user.activation_token}",  {token: user.activation_token}.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal ['user', 'spa_file_name', 'token'], resp.keys # returns {user: {}, token: abcd ...}

    # user is active and has related records
    user = User.first
    assert_equal nil, user.activation_token
    assert_equal true, user.active

    # check generated account_type
    assert_equal 1, Account.count
    assert_equal 1, user.accounts.count
    account = Account.first
    assert_equal true, account.default # account is set as default one
    assert_equal 'personal', account.type

    # check login trail
    assert_equal 1, user.login_trails.count
    login_trail = LoginTrail.last
    assert_equal '127.0.0.1', login_trail[:ip]
    assert_equal 'Chrome', login_trail[:browser_name]

    header "Authorization",  "Bearer #{resp['token']}"

    # get profile login history
    get '/profile/logins'
    assert last_response.ok?

    # get profile changes history
    get '/profile/changes'
    assert last_response.ok?

    # logout
    post '/logout'
    assert last_response.ok?

    # login now
    post '/login', {email: "pero@webteh.us",  password: "qwe123!Q"}.to_json
    assert last_response.ok?
    assert_equal 2, LoginTrail.count

  end

  def test_failed_logins
    # no payload
    post '/login'
    assert last_response.not_found?

    signup_user

    # fail login for 3 times
    post '/login', {email: "pero@webteh.us",  password: "invalid"}.to_json
    post '/login', {email: "pero@webteh.us",  password: "invalid"}.to_json
    post '/login', {email: "pero@webteh.us",  password: "invalid"}.to_json

    # disabled login after 3 tries
    user = User.first
    assert_equal 3, user[:failed_login_count]
    post '/login', {email: "pero@webteh.us",  password: "qwe123!Q"}.to_json
    assert last_response.forbidden?
    assert_equal 'To many failed login attempts', JSON.parse(last_response.body)['message']['title']

    # disabled login after failed_login_leeway - 5 sec has passed
    User.update_without_audit(user[:id], last_login_attempt_at: (user[:last_login_attempt_at] - WebPay.opts[:failed_login_leeway] + 5))
    post '/login', {email: "pero@webteh.us",  password: "qwe123!Q"}.to_json
    assert last_response.forbidden?

    # enabled login after failed_login_leeway + 5 sec has passed
    User.update_without_audit(user[:id], last_login_attempt_at: (user[:last_login_attempt_at] - WebPay.opts[:failed_login_leeway] - 5))
    post '/login', {email: "pero@webteh.us",  password: "qwe123!Q"}.to_json
    assert last_response.ok?
    assert_equal 0, User.first[:failed_login_count]
  end

end

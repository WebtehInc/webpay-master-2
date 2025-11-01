require_relative "../integration_helper"

class TestResetPassword < Test

  def test_reset_password

    # register
    post '/signup', {title: "mr", first_name: "pero", last_name: "peric", phone: "12345678",
                    email: "pero@webteh.us", password: "qwe123!Q", country: "DZ", address: "address",
                    city: "city", zip: "12345", terms:true, birth_date: "1990-03-22"}.to_json
    assert last_response.ok?

    # cannot reset if not active
    post '/reset-password', {email: "pero@webteh.us"}.to_json
    assert last_response.forbidden?

    user = User.first

    # activate
    post "/activate-user/#{user.activation_token}",  {token: user.activation_token}.to_json
    assert last_response.ok?

    # reset password
    # invalid email
    post '/reset-password', {email: "invalid@webteh.us"}.to_json
    assert last_response.ok? # do not reveal non existing emails

    # valid email
    post '/reset-password', {email: "pero@webteh.us"}.to_json
    assert last_response.ok?
    assert_equal 'password reset done', JSON.parse(last_response.body)['message']

    user.reload
    assert user.reset_password_token # token is generated

    # get user for reset info
    get "/reset-password/#{user.reset_password_token}"
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal User::PUBLIC_ATTRS.size, resp.keys.size  # we print all public attrs
    assert_equal user.first_name, resp['first_name']      # we print user info when changing password

    post "/reset-password/#{user.reset_password_token}", {}.to_json
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal 1, resp.keys.size # 1 errors
    assert resp['password'] # password error, must be filled and strong

  end

end

require_relative "../integration_helper"

class TestOtp < Test

  def test_otp

    signup_user
    login_user

    # invalid
    post '/verify-otp', {otp: '123456'}.to_json
    assert last_response.unprocessable?

    # valid
    totp = ROTP::TOTP.new(User.first[:otp_code])
    post '/verify-otp', {otp: totp.now}.to_json
    assert last_response.ok?
  end

end

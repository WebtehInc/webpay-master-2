require_relative "../integration_helper"

class TestProfile < Test

  def test_edit_profile

    unauthorized? :post, '/profile/update'

    user = signup_user
    login_user

    # requires otp
    post '/profile/update'
    assert last_response.forbidden?

    # no payload
    authorize_with_otp
    post '/profile/update', {}.to_json
    assert last_response.unprocessable?
    assert_equal 5, JSON.parse(last_response.body).keys.size # 5 errors

    # change zip
    post '/profile/update', @user_updatable_attrs.merge(zip: '67890', password: 'qwert123!@#').to_json
    assert last_response.ok?
    assert_equal 1, user.changes.count

    get '/profile/changes'
    assert last_response.ok?
    assert_equal 1, JSON.parse(last_response.body).size # 1 audit
  end

end

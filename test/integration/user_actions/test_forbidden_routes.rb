require_relative "../integration_helper"

class TestForbiddenRoutes < Test

  # 403 - authorize! must be called in routing tree before this route
  def test_forbidden_routes

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

    # change zip
    post '/profile/update', @user_updatable_attrs.merge(zip: '67890').to_json
    assert last_response.ok?
  end

end

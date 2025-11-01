require_relative "../integration_helper"

class TestAccounts < Test

  def test_accounts

    unauthorized? :get, '/accounts'

    signup_user
    login_user

    get '/accounts'
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal 1, resp.size
    assert_equal 0, resp[0]['balance'] # we have this attr in account

    # cannot get previous account with other user
    signup_user email: 'second_user@webteh.us'
    login_user email: 'second_user@webteh.us'
    get '/accounts'
    assert last_response.ok?
    assert_equal 1, JSON.parse(last_response.body).size # we get one
    assert_equal 2, Account.count                       # but there are 2 in total
  end

  def test_edit_account

    user = signup_user
    login_user

    account_id = Account.first.id

    # requires otp
    post "accounts/#{account_id}/update"
    assert last_response.forbidden?

    # no payload
    authorize_with_otp
    post "accounts/#{account_id}/update"
    assert last_response.unprocessable?
    assert_equal 1, JSON.parse(last_response.body).keys.size

    # change title
    post "accounts/#{account_id}/update", {title: 'USD'}.to_json
    assert last_response.ok?
    assert_equal 1, user.changes.count
  end

end

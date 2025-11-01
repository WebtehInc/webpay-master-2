require_relative "../integration_helper"

class Transaction
  PER_PAGE = 1 # to check pagination headers
end

class TestTransactions < Test

  def test_transactions

    unauthorized? :get, '/transactions/1'

    signup_user
    login_user
    generate_transaction account_id: Account.first.id

    post '/transactions/1'

    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal 1, resp.size
    assert_equal 'approved', resp[0]['status'] # we have this attr in transactions
    assert_equal 1, last_response.headers['X-per-page']
    assert_equal 1, last_response.headers['X-total-count']

    # cannot get previous transactions with other user
    signup_user email: 'second_user@webteh.us'
    login_user email: 'second_user@webteh.us'
    post '/transactions/1'
    assert last_response.ok?
    assert_equal [], JSON.parse(last_response.body)
  end

end

require_relative "../integration_helper"

class TestCustomerBalanceInquiry < Test

  def test_customer_balance_inquiry

    unauthorized? :post, '/customer-balance-inquiry'

    signup_user
    login_user

    account  = Account.first
    operator = generate_operator
    customer = generate_customer

    # no payload
    post '/customer-balance-inquiry', {}.to_json
    assert last_response.unprocessable?
    assert_equal 3, JSON.parse(last_response.body).keys.size # 3 errors

    # check balance
    post '/customer-balance-inquiry', {operator_code: operator.code, customer_number: customer.number, account_id: account.id}.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert resp['balance_info']
    assert_equal customer.balance, resp['customer']['balance']

  end

end

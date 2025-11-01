require_relative "../integration_helper"

class TestLimitsForPrepaid < Test

  def test_limits_for_prepaid

    signup_user
    login_user

    account  = Account.first
    authorize_with_otp

    # pagatinu
    # TEST_METER_NUMBERS = %W( 04229889888 04167587288 04111111110 04229889888 04167587288 04229889888 04167587288 )
    customer_number = '04229889888'
    operator = generate_operator name: 'Pagatinu', type: 'prepaid', code: 'pa'

    account.update balance: 500000

    # import limit fixtures
    Limit.instance_eval {serializer file_path: './test/fixtures', file_name: "limits.json"}
    Limit.send(:save_to_db_from_file!, true)

    # buy 3 prepaids; limit is 3 in fixtures
    amount = 100
    buy_prepaid(operator, customer_number, account, amount)
    buy_prepaid(operator, customer_number, account, amount)
    buy_prepaid(operator, customer_number, account, amount)

    # limit now by count
    decline_prepaid(operator, customer_number, account, amount, LIMIT_COUNT_MSG)

    # reset counts
    Transaction.dataset.delete

    # buy 2 prepaids for 20000; limit is 21000 in fixtures
    amount = 10000
    buy_prepaid(operator, customer_number, account, amount)
    buy_prepaid(operator, customer_number, account, amount)

    # limit now by volume
    decline_prepaid(operator, customer_number, account, amount, LIMIT_VOLUME_MSG)

  end

  # helpers for approve/decline
  def buy_prepaid(operator, customer_number, account, amount)
    post '/buy-prepaid', {  operator_code: operator.code, customer_number: customer_number, amount: amount,
                            account_id: account.id, systan: 613588667, client_datetime: "2016-10-04 11:19:08 +0700"  }.to_json
    assert last_response.ok?
  end

  def decline_prepaid(operator, customer_number, account, amount, resp_msg)
    post '/buy-prepaid', {  operator_code: operator.code, customer_number: customer_number, amount: amount,
                            account_id: account.id, systan: 613588667, client_datetime: "2016-10-04 11:19:08 +0700" }.to_json
    assert last_response.unprocessable?
    assert_equal resp_msg, JSON.parse(last_response.body)['amount'][0]
  end

end

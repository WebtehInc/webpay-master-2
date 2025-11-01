require_relative "../integration_helper"

class TestLimitsForBuyVoucher < Test

  def test_limits_for_buy_voucher

    signup_user
    login_user

    account  = Account.first

    operator = generate_operator type: 'voucher', min_amount: 10
    4.times{|n| generate_voucher name: 'V 10 USD', price: 1000, value: "voucher_#{n}"}
    3.times{|n| generate_voucher name: 'V 100 USD', price: 10000, value: "voucher_#{4+n}"}

    authorize_with_otp

    account.update balance: 100000

    # import limit fixtures
    Limit.instance_eval {serializer file_path: './test/fixtures', file_name: "limits.json"}
    Limit.send(:save_to_db_from_file!, true)

    # buy 3 voucher; limit is 3 in fixtures
    buy_voucher('V 10 USD', account.id)
    buy_voucher('V 10 USD', account.id)
    buy_voucher('V 10 USD', account.id)

    # limit now by count
    decline_buy_voucher('V 10 USD', account.id, LIMIT_COUNT_MSG)

    # reset counts
    Transaction.dataset.delete

    # buy 2 voucher for 20000; limit is 21000 in fixtures
    buy_voucher('V 100 USD', account.id)
    buy_voucher('V 100 USD', account.id)

    # limit now by volume
    decline_buy_voucher('V 100 USD', account.id, LIMIT_VOLUME_MSG)

  end

  # helpers for approve/decline
  def buy_voucher(name, account_id)
    post '/buy-voucher', { name: name, account_id: account_id }.to_json
    assert last_response.ok?
  end

  def decline_buy_voucher(name, account_id, resp_msg)
    post '/buy-voucher', { name: name, account_id: account_id }.to_json
    assert last_response.unprocessable?
    assert_equal resp_msg, JSON.parse(last_response.body)['name'][0]
  end

end

require_relative "../integration_helper"
require "active_support"
require "active_support/core_ext/numeric"

class TestLimitsForPayBill < Test

  def test_limits_for_pay_bill

    user = signup_user
    login_user

    account  = Account.first
    operator = generate_operator type: 'bill', min_amount: 10
    customer = generate_customer
    authorize_with_otp

    amount = 100
    account.update balance: 100 * amount


    # import limit fixtures
    Limit.instance_eval {serializer file_path: './test/fixtures', file_name: "limits.json"}
    Limit.send(:save_to_db_from_file!, true)

    # personalize count limit - override 3 with 4 and it is expired
    user.add_limit  category: 'Transaction', account_type: 'personal', user_type: 'basic', transaction_type: 'bill', amount: 4, currency: 'USD',
                    active: true, period: 1, period_type: 'day', type: 'count', debit_or_credit: 'debit', valid_until: Time.now - 1.day

    # personalize volume limit - override 210 with 350 and it is expired
    user.add_limit  category: 'Transaction', account_type: 'personal', user_type: 'basic', transaction_type: 'bill', amount: 350, currency: 'USD',
                    active: true, period: 1, period_type: 'day', type: 'volume', debit_or_credit: 'debit', valid_until: Time.now - 1.day


    ###### TEST GLOBAL LIMITS

    # pay 3 bills; limit is 3 in fixtures
    pay_bill(operator.code, customer.number, amount/10, account.id)
    pay_bill(operator.code, customer.number, amount/10, account.id)
    pay_bill(operator.code, customer.number, amount/10, account.id)

    # limit now by count
    decline_bill(operator.code, customer.number, amount, account.id, LIMIT_COUNT_MSG)

    # reset counts
    Transaction.dataset.delete

    # pay 2 bills; limit is 210 in fixtures
    pay_bill(operator.code, customer.number, amount, account.id)
    pay_bill(operator.code, customer.number, amount, account.id)

    # limit now by volume
    decline_bill(operator.code, customer.number, 10, account.id, LIMIT_VOLUME_MSG)


    ###### TEST PERSONAL LIMITS

    # personal limits are now fresh
    user.limits_dataset.update valid_until: Time.now + 1.day

    # pay one extra
    pay_bill(operator.code, customer.number, amount, account.id)

    # limit now by volume
    decline_bill(operator.code, customer.number, 50, account.id, LIMIT_VOLUME_MSG)

    # pay one extra
    pay_bill(operator.code, customer.number, 10, account.id)

    # limit now by count
    decline_bill(operator.code, customer.number, 10, account.id, LIMIT_COUNT_MSG)
  end

  # helpers for approve/decline
  def pay_bill(operator_code, customer_number, amount, account_id)
    post '/pay-bill', { operator_code: operator_code, customer_number: customer_number, amount: amount,
                        account_id: account_id }.to_json
    assert last_response.ok?
  end

  def decline_bill(operator_code, customer_number, amount, account_id, resp_msg)
    post '/pay-bill', { operator_code: operator_code, customer_number: customer_number, amount: amount,
                        account_id: account_id }.to_json
    assert last_response.unprocessable?
    assert_equal resp_msg, JSON.parse(last_response.body)['amount'][0]
  end


end

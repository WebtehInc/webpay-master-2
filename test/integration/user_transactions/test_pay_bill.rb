require_relative "../integration_helper"

class TestPayBill < Test

  def test_pay_bill

    unauthorized? :post, '/pay-bill'

    user = signup_user
    login_user

    account  = Account.first
    operator = generate_operator type: 'bill'
    customer = generate_customer

    # requires otp
    forbidden? :post, '/pay-bill'

    authorize_with_otp

    # no payload
    post '/pay-bill', {}.to_json
    assert last_response.unprocessable?
    assert_equal 4, JSON.parse(last_response.body).keys.size # 4 errors

    paying_amount = 12345

    # not enough funds
    post '/pay-bill', { operator_code: operator.code, customer_number: customer.number, amount: paying_amount,
                        account_id: account.id }.to_json
    assert last_response.unprocessable?
    assert_equal 'not enough funds', JSON.parse(last_response.body)['amount'][0]

    account.update balance: 3 * paying_amount

    # below operator min. amount
    under_limit_amount = operator.min_amount - 1
    post '/pay-bill', { operator_code: operator.code, customer_number: customer.number, amount: under_limit_amount,
                        account_id: account.id }.to_json
    assert last_response.unprocessable?
    assert_equal 'under operator minimum amount', JSON.parse(last_response.body)['amount'][0]

    # pay it now
    post '/pay-bill', { operator_code: operator.code, customer_number: customer.number, amount: paying_amount,
                        account_id: account.id }.to_json
    assert last_response.ok?

    # response json
    resp = JSON.parse(last_response.body)
    pp resp
    assert_equal operator.name, resp['Operator']
    assert_equal customer.number, resp['Account number']
    assert resp['Balance']

    account.reload
    trx = Transaction.first
    assert_equal customer.balance + paying_amount, customer.reload.balance  # new balance for customer
    assert_equal 2 * paying_amount, account.balance # we spent some money
    assert_equal paying_amount, trx.amount          # trx has paying amount
    assert_equal 'debit', trx.type                  # trx is bill type
    assert_equal 'bill', trx.transaction_type       # trx is debit
    assert_equal trx.balance, account.balance       # reflect balance in trx
    assert_equal trx.operator_code, operator.code   # copy operator code
    assert_equal trx.customer_number, customer.number   # copy customer_number
    assert_equal operator.name, trx.description
    assert trx.note.include? "Operator: #{operator.name} | Account number: #{customer.number} | Balance: " # match first part of string

    # pay with fee and notification
    Fee.instance_eval {serializer file_path: './test/fixtures', file_name: "fees.json"}
    Fee.send(:save_to_db_from_file!, true)

    user.settings['notifications']['bill'] = true
    user.save

    paying_amount = 123
    post '/pay-bill', { operator_code: operator.code, customer_number: customer.number, amount: paying_amount,
                        account_id: account.id }.to_json
    assert last_response.ok?

    assert_equal 3, Transaction.count

    fee_trx = Transaction.last
    fee_amount = Fee.where(transaction_type: 'bill', user_type: user.type, account_type: account.type).first.amount
    assert_equal fee_amount, fee_trx.amount

    old_balance = account.balance
    assert_equal old_balance - paying_amount - fee_amount, account.reload.balance
  end

end

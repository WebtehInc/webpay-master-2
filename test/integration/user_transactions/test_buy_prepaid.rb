require_relative "../integration_helper"

class TestBuyPrepaid < Test

  # test_api_sell_prepaid_pagatinu
  def test_buy_prepaid_pagatinu

    unauthorized? :post, '/buy-prepaid'

    user = signup_user
    login_user

    account  = Account.first

    # pagatinu
    # TEST_METER_NUMBERS = %W( 04229889888 04167587288 04111111110 04229889888 04167587288 04229889888 04167587288 )
    test_token = '01234567890123456789'
    customer_number = '04229889888'
    operator = generate_operator name: 'Pagatinu', type: 'prepaid', code: 'pa'

    # requires otp
    forbidden? :post, '/buy-prepaid'

    authorize_with_otp

    # no payload
    post '/buy-prepaid', {}.to_json
    assert last_response.unprocessable?
    assert_equal 4, JSON.parse(last_response.body).keys.size # 4 errors

    paying_amount = 12345

    # not enough funds
    post '/buy-prepaid', {  operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
      account_id: account.id, systan: 613588667, client_datetime: "2016-10-04 11:19:08 +0700" }.to_json
    assert last_response.unprocessable?
    assert_equal ['not enough funds'], JSON.parse(last_response.body)['amount']

    # PAY IT NOW: NORMAL FLOW
    account.update balance: 3 * paying_amount
    post '/buy-prepaid', {  operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
      account_id: account.id, systan: 613588667, client_datetime: "2016-10-04 11:19:08 +0700" }.to_json
    assert last_response.ok?, "last response was not OK in normal flow"

    assert_successful_pagatinu_last_response account: account, operator: operator, test_token: test_token,
      paying_amount: paying_amount

    # PAY IT NOW: ERROR + LAST_ADVICE FLOW
    account.update balance: 3 * paying_amount

    request = {  operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
      account_id: account.id, systan: 613588667, client_datetime: "2016-10-04 11:19:08 +0700" }
    PagafasilImporters::MockPagatinuClient.stub_any_instance :credit_vend_request, -> { raise Faraday::TimeoutError.new } do
      post '/buy-prepaid', request.to_json
    end
    refute last_response.ok?

    post '/buy-prepaid', request.merge(repeat: true).to_json
    assert last_response.ok?

    assert_successful_pagatinu_last_response account: account, operator: operator, test_token: test_token,
      paying_amount: paying_amount

    # invalid customer_number
    post '/buy-prepaid', {  operator_code: operator.code, customer_number: '12345', amount: paying_amount,
      account_id: account.id, systan: 613588667, client_datetime: "2016-10-04 11:19:08 +0700" }.to_json
    assert last_response.unprocessable?
    assert JSON.parse(last_response.body)['customer_number']

    # service error
    # post '/buy-prepaid', {  operator_code: operator.code, customer_number: customer_number, amount: 20000,
    #                         account_id: account.id }.to_json
    # assert last_response.unprocessable?
    # assert_equal "#{operator.name}: Invalid customer", JSON.parse(last_response.body)['error']

    # buy with fee
    Fee.instance_eval {serializer file_path: './test/fixtures', file_name: "fees.json"}
    Fee.send(:save_to_db_from_file!, true)

    post '/buy-prepaid', {  operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
      account_id: account.id, systan: 613588667, client_datetime: "2016-10-04 11:19:08 +0700" }.to_json
    assert last_response.ok?

    assert_equal 4, Transaction.count

    fee_trx = Transaction.last
    fee_amount = Fee.where(transaction_type: 'voucher', user_type: user.type, account_type: account.type).first.amount
    assert_equal fee_amount, fee_trx.amount

    old_balance = account.balance
    assert_equal old_balance - paying_amount - fee_amount, account.reload.balance
  end


  private

  def assert_successful_pagatinu_last_response options = {}
    account = options.delete(:account)
    operator = options.delete(:operator)
    test_token = options.delete(:test_token)
    paying_amount = options.delete(:paying_amount)

    # response json
    resp = JSON.parse(last_response.body)
    pp resp
    assert_equal operator.name, resp['Operator'], 'operator name is off'
    assert_equal test_token.in_groups_by(4), resp['Code'], 'test_token is off'
    assert resp['Receipt number'], 'receipt number missing'
    assert resp['Account'], 'account missing'
    assert resp['Name'], 'name missing'
    assert resp['Meter'], 'meter missing'
    assert resp['Tariff'], 'tariff missing'
    assert resp['Cost'], 'cost missing'
    assert resp['Energy'], 'energy missing'
    assert resp['Info'], 'info missing'

    account.reload
    trx = Transaction.last
    assert_equal 2 * paying_amount, account.balance, 'balance is off'  # we spent some money
    assert_equal paying_amount, trx.amount, 'paying amount is off'          # trx has paying amount
    assert_equal 'debit', trx.type                  # trx is bill type
    assert_equal 'prepaid', trx.transaction_type    # trx is prepaid
    assert_equal trx.balance, account.balance       # reflect balance in trx
    assert_equal trx.operator_code, operator.code   # copy operator code
    assert trx.description.include? operator.name   # match first part of string
    assert trx.note.include? "Operator: #{operator.name} | Code: " # match first part of string
    response_message = trx.response_message.split(' ')  # KWh units, ie. '7 KWh'
    assert_equal 'kwh', response_message.last.downcase
    assert response_message.first.to_i > 1              # mock returns random number
  end

end

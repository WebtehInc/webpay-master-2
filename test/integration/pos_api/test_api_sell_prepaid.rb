require_relative "../integration_helper"

class TestApiSellPrepaid < Test

  # pagatinu
  def test_api_sell_prepaid_pagatinu
    max_amount = 500
    min_amount = 10
    credit_limit  = max_amount * 2 + 100 # one regular sell, one with advice flag
    paying_amount = max_amount - 1
    systan = '00001234'
    client_datetime = Time.now.to_s

    user = signup_user
    account  = generate_business_account user
    account.update credit_limit: credit_limit, max_amount: max_amount, min_amount: min_amount
    terminal = generate_terminal account_id: account.id

    # pagatinu
    # TEST_METER_NUMBERS = %W( 04229889888 04167587288 04111111110 04229889888 04167587288 04229889888 04167587288 )
    customer_number = '04229889888'
    operator = generate_operator name: 'Pagatinu', type: 'prepaid', code: 'pa'
    currency = operator.currency

    # create cashier
    login_user
    cashier, cashier_pin = create_cashier terminal

    digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + operator.code + customer_number +
                                      paying_amount.to_s + currency + systan)

    # no payload
    post '/api/sell-prepaid', {}.to_json
    assert last_response.unprocessable?
    assert_equal 14, JSON.parse(last_response.body).keys.size

    # invalid access_token
    post '/api/sell-prepaid', { operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
                                currency: currency, access_token: 'any', digest: 'any',
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash'}.to_json
    assert last_response.unprocessable?
    assert_equal 'unknown or disabled terminal', JSON.parse(last_response.body)['access_token'][0]

    # invalid digest
    post '/api/sell-prepaid', { operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
                                currency: currency, access_token: terminal.access_token, digest: 'invalid',
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash' }.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['digest'][0]

    # invalid pin
    post '/api/sell-prepaid', { operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
                                currency: currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash', cashier_pin: 'wrong', cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'invalid cashier pin', JSON.parse(last_response.body)['cashier_pin'][0]

    # inactive cashier
    cashier.update(active: false)
    post '/api/sell-prepaid', { operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
                                currency: currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash', cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'invalid cashier pin', JSON.parse(last_response.body)['cashier_pin'][0]
    cashier.update(active: true)


    # missmatch payment_method_type
    post '/api/sell-prepaid', { operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
                                currency: currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'card',
                                payment_method_type: MPOS_CHECK_PAYMENT_METHOD_TYPES[0][:payment_method_type], cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'payment type mismatch', JSON.parse(last_response.body)['payment_method'][0]

    # invalid payment_method_type
    post '/api/sell-prepaid', { operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
                                currency: currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'card', payment_method_type: 'unknown',
                                cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert JSON.parse(last_response.body)['payment_method_type']

    # after hours
    post '/api/sell-prepaid', { operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
                                currency: currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'card', payment_method_type: 'debit',
                                cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'after hours, store is closed', JSON.parse(last_response.body)['access_token'][0]

    # sell now
    cashier.update(manager: true) # promote cashier to manager
    time = Time.now
    terminal.update(opening_hours: time.hour - 1, opening_minutes: time.min - 1, closing_hours: time.hour + 1, closing_minutes: time.min + 1) # open store
    payload = { operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
                currency: currency, access_token: terminal.access_token, digest: digest,
                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                client_datetime: client_datetime, payment_method: 'card', payment_method_type: 'debit',
                cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    post '/api/sell-prepaid', payload

    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    trx = Transaction.first

    # response fields
    assert_equal trx.id, resp['id']
    assert_equal '1.0.0.', resp['api_version']
    assert_equal '1.0.0.', resp['application_version']
    assert_equal cashier.full_name, resp['cashier']
    assert resp['prepaid_code']
    assert resp['info']
    assert resp['info']['Receipt number']
    assert resp['info']['Account']
    assert resp['info']['Name']
    assert resp['info']['Meter']
    assert resp['info']['Tariff']
    assert resp['info']['Cost']
    assert resp['info']['Energy']
    assert resp['info']['Info']

    # exposure
    account.reload
    assert_equal paying_amount, account.exposure_amount                     # new exposure for account

    # transactions attrs
    assert_equal paying_amount, trx.amount          # trx has paying amount
    assert_equal systan, trx.systan                 # trx has systan
    assert_equal 'credit', trx.type                 # trx is credit
    assert_equal 'prepaid_mpos', trx.transaction_type  # trx is bill_mpos
    assert_equal account.balance, trx.balance       # reflect balance in trx
    assert_equal '1.0.0.', trx.api_version
    assert_equal '1.0.0.', trx.application_version
    assert_equal client_datetime, trx.client_datetime.to_s
    assert_equal 'card', trx.payment_method
    assert_equal 'debit', trx.payment_method_type
    assert_equal terminal.services_batch_number, trx.services_batch_number # batch number
    assert_equal operator.code, trx.operator_code       # operator code
    assert_equal customer_number, trx.customer_number   # customer_number
    response_message = trx.response_message.split(' ')  # KWh units, ie. '7 KWh'
    assert_equal 'KWh', response_message.last
    assert response_message.first.to_i > 1              # mock returns random number

    # asert relations
    assert account.transactions.first   # account has trx
    assert terminal.transactions.first  # terminal has trx
    assert cashier.transactions.first   # cashier has trx

    # check response digest
    assert_equal Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + resp['prepaid_code'].to_s), resp['digest']

    # retry to get cached response
    post '/api/sell-prepaid/retry', payload
    assert last_response.ok?
    assert_equal resp, JSON.parse(last_response.body)
    assert_equal 1, Transaction.count

    # sell again with advice flag
    advice_flag_key_name = "#{customer_number}_advice_flag"
    MemoryStore.set(advice_flag_key_name, true, 60) # cache advice flag
    time = Time.now
    payload = { operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
                currency: currency, access_token: terminal.access_token, digest: digest,
                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                client_datetime: client_datetime, payment_method: 'card', payment_method_type: 'debit',
                cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    post '/api/sell-prepaid', payload

    assert last_response.ok?
    assert_equal Transaction.count, 2 # second sell

    resp = JSON.parse(last_response.body)
    assert_equal resp['info']['Advice'], "Yes"    # advice falg is printed
    refute MemoryStore.get(advice_flag_key_name)  # flag is removed from cache

    # hit max amount limit
    paying_amount = max_amount + 1
    post '/api/sell-prepaid', { operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
                                currency: currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash',
                                payment_method_type: 'debit', cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'over maximum amount', JSON.parse(last_response.body)['amount'][0]

    # hit min amount limit
    paying_amount = min_amount - 1
    post '/api/sell-prepaid', { operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
                                currency: currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash',
                                payment_method_type: 'debit', cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'under minimum amount', JSON.parse(last_response.body)['amount'][0]

    # hit credit limit
    paying_amount = max_amount - 1
    post '/api/sell-prepaid', { operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
                                currency: currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash',
                                payment_method_type: 'debit', cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'credit limit exceeded', JSON.parse(last_response.body)['amount'][0]


    # pay for inactive terminal
    terminal.update(active: false)
    post '/api/sell-prepaid', { operator_code: operator.code, customer_number: customer_number, amount: paying_amount,
                                currency: currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash',
                                payment_method_type: 'debit', cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'unknown or disabled terminal', JSON.parse(last_response.body)['access_token'][0]


    # invalid customer_number
    account.update credit_limit: 1000000, max_amount: 100000, min_amount: 1
    terminal.update(active: true)
    customer_number = '1234'
    digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + operator.code + customer_number +
                                      '10000' + currency + systan)
    post '/api/sell-prepaid', { operator_code: operator.code, customer_number: customer_number, amount: 10000,
                                currency: currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'card', payment_method_type: 'debit',
                                cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert JSON.parse(last_response.body)['customer_number']

    # service error
    # digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + operator.code + customer_number +
    #                                   '20000' + currency + systan)
    # post '/api/sell-prepaid', { operator_code: operator.code, customer_number: customer_number, amount: 20000,
    #                             currency: currency, access_token: terminal.access_token, digest: digest,
    #                             systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
    #                             client_datetime: client_datetime, payment_method: 'card', payment_method_type: 'debit',
    #                             cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    # assert last_response.unprocessable?
    # assert_equal "#{operator.name}: Invalid customer", JSON.parse(last_response.body)['error']
  end

end

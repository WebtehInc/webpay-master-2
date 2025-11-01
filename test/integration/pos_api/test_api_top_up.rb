require_relative "../integration_helper"

class TestApiTopUp < Test

  def test_api_top_up

    # merchant setup
    merchant = signup_user(email: 'merchant@email.com')
    account  = generate_business_account merchant
    terminal = generate_terminal account_id: account.id, batch_limit: 1000000, amount_limit: 100000
    login_user(email: 'merchant@email.com')
    cashier, cashier_pin = create_cashier terminal

    # set limits
    account.update credit_limit: 1000000, max_amount: 100000, min_amount: 10

    # user setup
    user = signup_user(email: 'user@email.com')
    target_account = user.accounts.first
    card_pin = '1234'
    card = generate_card user, pin_block: card_pin
    card_number = card.pan

    # trx setup
    systan = '00001234'
    client_datetime = Time.now.to_s
    amount = 12345
    currency = target_account.currency

    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, card_number, amount, currency, systan)

    # no payload
    post 'api/top-up'
    assert last_response.unprocessable?
    assert_equal 12, JSON.parse(last_response.body).keys.size

    # invalid access_token
    post '/api/top-up', { amount: amount, currency: currency, access_token: 'any', digest: 'any', card_pin: card_pin, payment_method: 'card',
                          payment_method_type: 'debit', systan: systan, api_version: '1.0.0.', application_version: '1.0.0.', card_number: card_number,
                          client_datetime: client_datetime, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'unknown or disabled terminal', JSON.parse(last_response.body)['access_token'][0]

    # invalid digest
    post '/api/top-up', { amount: amount, currency: currency, access_token: 'any', digest: 'any', card_pin: card_pin, payment_method: 'card',
                          payment_method_type: 'debit', systan: systan, api_version: '1.0.0.', application_version: '1.0.0.', card_number: card_number,
                          client_datetime: client_datetime, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['digest'][0]

    # invalid cashier pin
    post '/api/top-up', { amount: amount, currency: currency, access_token: terminal.access_token, digest: digest, card_pin: card_pin, payment_method: 'card',
                          payment_method_type: 'debit', systan: systan, api_version: '1.0.0.', application_version: '1.0.0.', card_number: card_number,
                          client_datetime: client_datetime, cashier_pin: 'wrong', cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'invalid cashier pin', JSON.parse(last_response.body)['cashier_pin'][0]

    # inactive cashier
    cashier.update(active: false)
    post '/api/top-up', { amount: amount, currency: currency, access_token: terminal.access_token, digest: digest, card_pin: card_pin, payment_method: 'card',
                          payment_method_type: 'debit', systan: systan, api_version: '1.0.0.', application_version: '1.0.0.', card_number: card_number,
                          client_datetime: client_datetime, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'invalid cashier pin', JSON.parse(last_response.body)['cashier_pin'][0]
    cashier.update(active: true)

    # invalid target account
    post '/api/top-up', { amount: amount, currency: currency, access_token: terminal.access_token, digest: digest, card_pin: card_pin, payment_method: 'card',
                          payment_method_type: 'debit', systan: systan, api_version: '1.0.0.', application_version: '1.0.0.', card_number: '123321',
                          client_datetime: client_datetime, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert JSON.parse(last_response.body)['digest']

    # invalid target account by currency
    post '/api/top-up', { amount: amount, currency: 'EUR', access_token: terminal.access_token, digest: digest, card_pin: card_pin, payment_method: 'card',
                          payment_method_type: 'debit', systan: systan, api_version: '1.0.0.', application_version: '1.0.0.', card_number: card_number,
                          client_datetime: client_datetime, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal ['unknown target account'], JSON.parse(last_response.body)['card_number']

    # after hours / invalid card pin
    post '/api/top-up', { amount: amount, currency: currency, access_token: terminal.access_token, digest: digest, card_pin: '1111', payment_method: 'card',
                          payment_method_type: 'debit', systan: systan, api_version: '1.0.0.', application_version: '1.0.0.', card_number: card_number,
                          client_datetime: client_datetime, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'after hours, store is closed', JSON.parse(last_response.body)['access_token'][0]
    assert_equal 'is invalid', JSON.parse(last_response.body)['card_pin'][0]


    # top-up now
    time = Time.now
    terminal.update(opening_hours: time.hour - 1, opening_minutes: time.min - 1, closing_hours: time.hour + 1, closing_minutes: time.min + 1) # open store
    payload = { amount: amount, currency: currency, access_token: terminal.access_token, digest: digest, card_pin: card_pin, payment_method: 'card',
                payment_method_type: 'debit', systan: systan, api_version: '1.0.0.', application_version: '1.0.0.', card_number: card_number,
                client_datetime: client_datetime, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    post '/api/top-up', payload
    assert last_response.ok?
    resp = JSON.parse(last_response.body)

    assert_equal 2, Transaction.count

    # response fields
    assert_equal '1.0.0.', resp['api_version']
    assert_equal '1.0.0.', resp['application_version']
    assert_equal cashier.full_name, resp['cashier']

    # check user account
    assert_equal target_account.balance + amount, target_account.reload.balance

    # check card
    assert_equal 1, card.reload.access_count
    assert_equal terminal.id, card.last_access_terminal_id
    assert card.last_access_at

    # check merchant account
    account_with_old_values = account.values.dup
    assert_equal amount, account.reload.exposure_amount
    assert_equal account_with_old_values[:balance], account.balance # balance is unchanged
    assert_equal 0, account.balance # it stays empty

    # merchant transaction
    merchant_trx = account.transactions.first
    assert_equal amount, merchant_trx.amount
    assert_equal 'top_up_mpos', merchant_trx.transaction_type # check fields
    assert_equal 'credit', merchant_trx.type
    assert_equal 'approved', merchant_trx.status
    assert_equal cashier.id, merchant_trx.cashier_id

    # user transaction
    user_trx = target_account.transactions.first
    assert_equal amount, user_trx.amount
    assert_equal target_account.balance, user_trx.balance # reflect balance in trx
    assert_equal 'top_up', user_trx.transaction_type # check fields
    assert_equal 'credit', user_trx.type
    assert_equal 'approved', user_trx.status

    # relations
    assert_equal merchant_trx.id, user_trx.parent_id
    assert_equal 1, terminal.transactions.count
    assert_equal 1, account.transactions.count
    assert_equal 1, target_account.transactions.count
    assert_equal 1, user.transactions.count

    # check response digest
    assert_equal Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + merchant_trx.id.to_s), resp['digest']

    # retry to get cached response
    post '/api/top-up/retry', payload
    assert last_response.ok?
    assert_equal resp, JSON.parse(last_response.body)
    assert_equal 2, Transaction.count

    # retry to get new transaction
    Transaction.dataset.delete
    MemoryStore.flush_all
    post '/api/top-up/retry', payload
    assert last_response.ok?
    assert_equal 2, Transaction.count
    Transaction.dataset.delete

    # reset for top-up with account_number input
    time = Time.now
    account_number = target_account.account_number
    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, account_number, amount.to_s, currency, systan)
    post '/api/top-up', { amount: amount, currency: currency, access_token: terminal.access_token, digest: digest, payment_method: 'card',
                          payment_method_type: 'debit', systan: systan, api_version: '1.0.0.', application_version: '1.0.0.', account_number: account_number,
                          client_datetime: client_datetime, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)

    assert_equal 2, Transaction.count
  end

end

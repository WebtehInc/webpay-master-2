require_relative "../integration_helper"

class TestApiSellVoucher < Test


  def test_encrypt_decrypt
    # encryption, do this on create:
    v = Voucher.new(name: 'roko voucher', currency: 'RKK')
    encrypted_data = v.encrypted_sensitive_data(value: '12344321')
    v.value = encrypted_data[:value]
    v.default_key_label = encrypted_data[:key_label]
    v.save_changes

    # decryption, do this when you need to read sensitive data:
    v = Voucher.last
    sensitive_data = v.decrypted_sensitive_data
    assert_equal '12344321', sensitive_data[:value], "expected a different value after decryption"
  end

  def test_api_sell_voucher
    batch_limit = 600
    voucher_price = 500
    systan = '00001234'
    client_datetime = Time.now.to_s

    user = signup_user
    account  = generate_business_account user
    terminal = generate_terminal account_id: account.id, batch_limit: batch_limit
    operator = generate_operator

    # this product will trigger alert mail for bank
    Product.create name: 'Chippie 100', price: 10000, currency: 'USD', type: 'voucher', operator_code: 'ch', notify_quantity: 0
    # voucher  = generate_voucher price: voucher_price, value: 'BBBBBBBBBBBBBBBB'
    # voucher  = generate_voucher
    voucher  = generate_voucher price: voucher_price, value: 'AAAAAAAAAAAAAAAA'

    # alert for merchant
    account.settings['low_stock']= {'Chippie 100'=> 0}
    account.save

    # create cashier
    login_user
    cashier, cashier_pin = create_cashier terminal

    digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + voucher.name + systan)

    # no payload
    post '/api/sell-voucher', {}.to_json
    assert last_response.unprocessable?
    assert_equal 11, JSON.parse(last_response.body).keys.size

    # invalid access_token
    post '/api/sell-voucher', { name: 'any', access_token: 'any', digest: 'any',
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash', cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'unknown or disabled terminal', JSON.parse(last_response.body)['access_token'][0]

    # invalid digest
    post '/api/sell-voucher', { name: voucher.name, access_token: terminal.access_token, digest: 'invalid',
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash', cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['digest'][0]

    # invalid pin
    post '/api/sell-voucher', { name: voucher.name, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash', cashier_pin: 'wrong', cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'invalid cashier pin', JSON.parse(last_response.body)['cashier_pin'][0]

    # inactive cashier
    cashier.update(active: false)
    post '/api/sell-voucher', { name: voucher.name, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash', cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'invalid cashier pin', JSON.parse(last_response.body)['cashier_pin'][0]
    cashier.update(active: true)


    # missmatch payment_method_type
    post '/api/sell-voucher', { name: voucher.name, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'card',
                                payment_method_type: MPOS_CHECK_PAYMENT_METHOD_TYPES[0][:payment_method_type], cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'payment type mismatch', JSON.parse(last_response.body)['payment_method'][0]

    # out of stock with no stock record
    post '/api/sell-voucher', { name: voucher.name, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash',  payment_method_type: '',
                                cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'out of stock', JSON.parse(last_response.body)['name'][0]

    # after hours
    post '/api/sell-voucher', { name: voucher.name, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash',  payment_method_type: '',
                                cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'after hours, store is closed', JSON.parse(last_response.body)['access_token'][0]

    # sell it now
    stock = VoucherStock.create(name: voucher.name, quantity: 10)
    account.add_voucher_stock stock
    cashier.update(manager: true) # promote cashier to manager

    # new_session_keys = WebPay.opts[:crypto_client].new.generate_session_keys({}).except('action')  # generate keys
    # terminal.update(session_keys: new_session_keys)

    time = Time.now
    terminal.update(opening_hours: time.hour - 1, opening_minutes: time.min - 1, closing_hours: time.hour + 1, closing_minutes: time.min + 1) # open store
    payload = { name: voucher.name, access_token: terminal.access_token, digest: digest,
                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                client_datetime: client_datetime, payment_method: 'cash',  payment_method_type: '',
                cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    post '/api/sell-voucher', payload
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    trx = Transaction.first
    # pp trx.values.inspect

    # response fields
    # decrypt voucher value
    decrypted_voucher_value = resp['voucher_code']
    # decripted_voucher_value = WebPay.opts[:crypto_client].new.
    #                           decrypt(resp['voucher_code'],
    #                                   key: terminal.session_keys['data_key'],
    #                                   key_label: WebPay.opts[:crypto_client].new.default_tmk_key_label)

    # check voucher values
    assert_equal voucher.decrypted_sensitive_data[:value], decrypted_voucher_value
    assert_equal voucher.uid, resp['voucher_serial']

    assert_equal '1.0.0.', resp['api_version']
    assert_equal '1.0.0.', resp['application_version']
    assert_equal cashier.full_name, resp['cashier']

    # balances for account
    account.reload
    # assert_equal voucher.price, account.balance  # we have updated balance

    # voucher is sold
    assert_equal 'sold', voucher.reload.status    # voucher is sold

    # stock is decremented
    quantity = stock.quantity # !? bug for stock.quantity - 1
    assert_equal (quantity -1), stock.reload.quantity

    # transaction attrs
    assert_equal voucher.price, trx.amount            # trx has its amount
    assert_equal systan, trx.systan                   # trx has systan
    assert_equal 'credit', trx.type                   # trx is credit
    assert_equal 'voucher_mpos', trx.transaction_type # trx is voucher_mpos
    assert_equal trx.balance, account.balance         # reflect balance in trx
    assert_equal '1.0.0.', trx.api_version
    assert_equal '1.0.0.', trx.application_version
    assert_equal client_datetime, trx.client_datetime.to_s
    assert_equal 'cash', trx.payment_method
    assert_equal '', trx.payment_method_type
    assert_equal terminal.services_batch_number, trx.services_batch_number
    assert_equal trx.operator_code, voucher.operator_code # copy operator code

    # asert relations
    assert account.transactions.first   # account has trx
    assert cashier.transactions.first   # cashier has trx
    assert terminal.transactions.first  # terminal has trx
    assert_equal terminal.id, voucher.terminal_id # terminal has voucher (no relation in model)
    assert trx.voucher # trx has voucher

    # check response digest
    assert_equal Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + resp['voucher_code'].to_s), resp['digest']

    # retry to get cached response
    post '/api/sell-voucher/retry', payload
    assert last_response.ok?
    assert_equal resp, JSON.parse(last_response.body)
    assert_equal 1, Transaction.count

    # it is alredy sold, try again
    post '/api/sell-voucher', { name: voucher.name, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash', cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'unknown voucher', JSON.parse(last_response.body)['name'][0]

    # out of stock with stock record and qty == 0
    stock.update quantity: 0
    Transaction.dataset.delete
    post '/api/sell-voucher', { name: voucher.name, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash',  payment_method_type: '',
                                cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'out of stock', JSON.parse(last_response.body)['name'][0]

    # sell it now for inactive terminal
    terminal.update(active: false)
    post '/api/sell-voucher', { name: voucher.name, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                client_datetime: client_datetime, payment_method: 'cash', cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'unknown or disabled terminal', JSON.parse(last_response.body)['access_token'][0]
  end

end

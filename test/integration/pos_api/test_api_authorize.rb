require_relative "../integration_helper"

class TestApiAuthorize < Test

  def test_api_authorize

    access_token = 'authorize_api_access_token_2'
    terminal_key = 'authorize_api_terminal_key_3'

    # create terminal on switch
    # terminal_payload = {
    #   location_indicator: 'merchant',
    #   load_balancer: 'Vidanova::WebpayPos',
    #   status: 'active',
    #   authenticity_token: access_token,
    #   secret: terminal_key,
    #   name: 'WebPay Integration POS, test run',
    #   generate_tmk: true,
    #   mid: 'Terminal'
    # }

    # tacq = {
    #   acquirer_logid: "xml-sim",
    #   tid: "3141592",
    #   mid:"31415926535898",
    #   name:"XML-SIM Test Shop",
    #   city:"Oranjestad",
    #   address:"Otrobanda 3141",
    #   country:"AW",
    #   mcc:"5411",
    #   postal_code:"0000123",
    #   status:"active"
    # }

          # # terminal data on switch
          # remote_terminal = InfoSwitch::TerminalApi.new.create_or_update(terminal_payload)

          # # reuse tacq if its already created
          # remote_tacq = remote_terminal['tacqs'].first
          # tacq.merge!(id: remote_tacq['id']) if remote_tacq

          # # inactivate remote terminal
          # remote_terminal = InfoSwitch::TerminalApi.new.create_or_update(terminal_payload.merge(tacqs: [tacq.merge(status: 'inactive')]))
          # # pp remote_terminal

    user      = signup_user
    account   = generate_business_account user
    terminal  = generate_terminal account_id: account.id, accepted_cards: ['visa'], access_token: access_token, terminal_key: terminal_key

    # m = InfoSwitch::Mocks.new
    # EMV purchase:
    #   InfoSwitch::PosApi.new.authorize_or_purchase(m.emv_purchase)
    # Magstripe purchase:
    #   InfoSwitch::PosApi.new.authorize_or_purchase(m.magstripe_purchase)
    # Magstripe online PIN purchase (will fail with RC 5002):
    #   InfoSwitch::PosApi.new.authorize_or_purchase(m.magstripe_online_pin_purchase)
    # E-commerce ECI 5 purchase:
    #   InfoSwitch::PosApi.new.authorize_or_purchase(m.eci05_purchase)
    # Voice referral transaction:
    #   req = m.magstripe_purchase.merge(amount: 7053)
    #   resp = InfoSwitch::PosApi.new.authorize_or_purchase(req)
    #   InfoSwitch::PosApi.new.authorize_or_purchase(m.voice_referral_purchase(resp, req))
    # InfoSwitch::PosApi.new.authorize_or_purchase(
    #   InfoSwitch::Mocks.new.emv_purchase.merge(
    #     authenticity_token: terminal.access_token,
    #     secret: terminal.terminal_key
    #   )
    # )
    # InfoSwitch::Mocks.new.magstripe_purchase
    # {:authenticity_token=>"WebpayIntegrationPOS", :secret=>"secret", :transaction_type=>"purchase", :amount=>10001, :currency=>840,
    #  :created_at=>2018-09-03 19:08:03 -0400, :systan=>598353, :cardholder_authentication=>"signature", :card_data_entry=>"magstripe",
    #  :pan=>"4111111111111111", :track2=>"4111111111111111=17072011818341800000", :expiration_date=>"1707", :pos_entry_mode=>"012"}

    # create cashier
    login_user
    cashier, cashier_pin = create_cashier terminal

    currency = 'USD'
    amount = 43251
    systan = '123456789'
    transaction_type = 'card_authorization'
    client_datetime = Time.now.to_s

    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, systan, amount, currency)

    ### no payload
    post '/api/authorize', {}.to_json
    assert last_response.unprocessable?
    assert_equal 11, JSON.parse(last_response.body).keys.size # 13 errors

    ### invalid access_token
    post '/api/authorize', {access_token: 'any', digest: 'any',
                            api_version: '1.0.0.', application_version: '1.0.0.',
                            amount: amount, currency: currency, systan: systan,
                            transaction_type: transaction_type, client_datetime: client_datetime,
                            card_data: {}}.to_json
    assert last_response.unprocessable?
    assert_equal 'unknown or disabled terminal', JSON.parse(last_response.body)['access_token'][0]

    ### invalid digest
    post '/api/authorize', {access_token: terminal.access_token, digest: 'invalid',
                            api_version: '1.0.0.', application_version: '1.0.0.',
                            amount: amount, currency: currency, systan: systan,
                            transaction_type: transaction_type, client_datetime: client_datetime,
                            card_data: {}}.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['digest'][0]

    ### invalid pin
    post '/api/authorize', {access_token: terminal.access_token, digest: digest,
                            api_version: '1.0.0.', application_version: '1.0.0.',
                            amount: amount, currency: currency, systan: systan,
                            transaction_type: transaction_type, client_datetime: client_datetime,
                            cashier_pin: 'wrong', card_data: {}}.to_json
    assert last_response.unprocessable?
    assert_equal 'invalid cashier pin', JSON.parse(last_response.body)['cashier_pin'][0]

    ### inactive cashier
    cashier.update(active: false)
    post '/api/authorize', {access_token: terminal.access_token, digest: digest,
                            api_version: '1.0.0.', application_version: '1.0.0.',
                            amount: amount, currency: currency, systan: systan,
                            transaction_type: transaction_type, client_datetime: client_datetime,
                            cashier_pin: cashier_pin, cashier_id: cashier.id, card_data: {}}.to_json
    assert last_response.unprocessable?
    assert_equal 'invalid cashier pin', JSON.parse(last_response.body)['cashier_pin'][0]
    cashier.update(active: true)

    ### after hours
    post '/api/authorize', {access_token: terminal.access_token, digest: digest,
                            api_version: '1.0.0.', application_version: '1.0.0.',
                            amount: amount, currency: currency, systan: systan,
                            transaction_type: transaction_type, client_datetime: client_datetime,
                            cashier_pin: cashier_pin, cashier_id: cashier.id, card_data: {}}.to_json
    assert last_response.unprocessable?
    assert_equal 'after hours, store is closed', JSON.parse(last_response.body)['access_token'][0]

    # open store
    time = Time.now
    terminal.update(opening_hours: time.hour - 1, opening_minutes: time.min - 1,
                    closing_hours: time.hour + 1, closing_minutes: time.min + 1)

    wallet_input = {
      access_token: terminal.access_token, digest: digest,
      api_version: '1.0.0.', application_version: '1.0.0.',
      amount: amount, currency: currency, systan: systan,
      transaction_type: transaction_type, client_datetime: client_datetime,
      cashier_pin: cashier_pin, cashier_id: cashier.id
    }

          # inctive remote terminal
          # card_data = InfoSwitch::Mocks.new.magstripe_purchase.except(:authenticity_token, :secret)
          # post '/api/authorize', wallet_input.merge(card_data: card_data).to_json
          # resp = JSON.parse(last_response.body)
          # assert last_response.unprocessable?
          # assert_equal 'No active acquiring accounts', resp['acquirer_data']['response_message']

          # # activate remote terminal
          # InfoSwitch::TerminalApi.new.create_or_update(terminal_payload.merge(tacqs: [tacq.merge(status: 'active')]))


    # AUTHORIZATION with empty card_data - InfoSwitch::PosApi response
    $mock_response_for_validation_error = JSON.parse(
      '{"request_id":23,"response_id":24,"acquirer":"xml-sim","mid":"31415926535898","tid":"3141592","authenticity_token":"wp_access_token_1",
      "systan":668,"approval_code":null,"emv_data":null,"reference_number":20011,"acquirer_response_code":null,"acquirer_response_message":null,
      "response_code":"5001","response_message":"validation error: card_data_entry is not on list","status":"declined","transaction_type":"authorization",
      "dcc_performed":false,"amount":12300,"currency":840,"billing_amount":12300,"billing_currency":840,"currency_exchange_margin":0,
      "currency_exchange_rate":1.0,"currency_exchange_provider":null,"error":"validation error: card_data_entry is not on list"}'
    )
    CardAuthorization.instance_eval do
      def process!(method_, terminal, params)
        $mock_response_for_validation_error # InfoSwitch::PosApi response
      end
    end

    ### DECLINED 5001 - card_data_entry is not on list
    post '/api/authorize', wallet_input.merge(card_data: {amount: amount, currency: CURRENCY_CODES[currency]}).to_json
    resp = JSON.parse(last_response.body)
    assert last_response.ok?

    # check balance
    assert_equal 0, account.reload.balance

    trx = Transaction.last

    # test trx
    assert_equal 'declined', trx.status                 # declined
    assert_equal '5001', trx.response_code              # code
    assert_equal 'credit', trx.type                     # trx is debit
    assert_equal 'card_authorization', trx.transaction_type  # trx is authorization
    assert_equal terminal.account.id, trx.account_id    # has account
    assert_equal terminal.id, trx.terminal_id           # has terminal
    assert_equal amount, trx.amount                     # amount
    assert_equal 0, trx.balance                         # running balance
    assert_equal '1.0.0.', trx.api_version
    assert_equal '1.0.0.', trx.application_version
    assert_equal client_datetime, trx.client_datetime.to_s

    # test response fields
    assert_equal trx.id, resp['id']
    assert_equal '1.0.0.', resp['api_version']
    assert_equal '1.0.0.', resp['application_version']
    assert_equal cashier.full_name, resp['cashier']

    # check digest
    assert_equal Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, systan), resp['digest']

    # check acquirer_data fields
    assert resp['acquirer_data'].keys.include?('approval_code') # nil
    assert resp['acquirer_data']['reference_number']
    assert resp['acquirer_data']['systan']
    assert_equal 'declined', resp['acquirer_data']['status']
    assert_equal '5001', resp['acquirer_data']['response_code']
    assert_equal 'validation error: card_data_entry is not on list', resp['acquirer_data']['response_message']
    assert_equal 'authorization', resp['acquirer_data']['transaction_type']

    # AUTHORIZATION with valid input, types are card_authorization or card_sale - InfoSwitch::PosApi response
    $mock_response_for_valid_input = JSON.parse(
      '{"request_id":23,"response_id":24,"acquirer":"xml-sim","mid":"31415926535898","tid":"3141592","authenticity_token":"wp_access_token_1",
      "systan":668,"approval_code":null,"emv_data":null,"reference_number":20011,"acquirer_response_code":null,"acquirer_response_message":null,
      "response_code":"0000","response_message":"transaction approved","status":"approved","transaction_type":"authorization",
      "dcc_performed":false,"amount":12300,"currency":840,"billing_amount":12300,"billing_currency":840,"currency_exchange_margin":0,
      "currency_exchange_rate":1.0,"currency_exchange_provider":null}'
    )
    CardAuthorization.instance_eval do
      @currency = currency; @amount = amount
      def process!(method_, terminal, params)
        $mock_response_for_valid_input.merge(currency: @currency, amount: @amount)
      end
    end

    ### AUTHORIZED 0000
    # We dont care about any of original card data except amount and currency, its pass through mode
    # card_data = {card_data: InfoSwitch::Mocks.new.magstripe_purchase.except(:authenticity_token, :secret)}
    card_data = {card_data: {amount: amount, currency: CURRENCY_CODES[currency], pan: 1234567890}}
    post '/api/authorize', wallet_input.merge(card_data).to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)

    # check new balance
    account.reload
    assert_equal 0, account.balance

    # test trx
    trx = Transaction.last
    assert_equal 'approved', trx.status                 # approved
    assert_equal '0000', trx.response_code              # code
    assert_equal 'credit', trx.type                     # trx is debit
    assert_equal 'card_authorization', trx.transaction_type  # trx is authorization
    assert_equal terminal.account.id, trx.account_id    # has account
    assert_equal terminal.id, trx.terminal_id           # has terminal
    assert_equal amount, trx.amount                     # amount
    assert_equal '1.0.0.', trx.api_version
    assert_equal '1.0.0.', trx.application_version
    assert_equal client_datetime, trx.client_datetime.to_s

    # test response fields
    assert_equal trx.id, resp['id']
    assert_equal '1.0.0.', resp['api_version']
    assert_equal '1.0.0.', resp['application_version']
    assert_equal cashier.full_name, resp['cashier']

    # check digest
    assert_equal Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, systan), resp['digest']

    # check acquirer_data fields
    assert_equal 'approved', resp['acquirer_data']['status']
    assert_equal '0000', resp['acquirer_data']['response_code']
    # assert_equal systan, resp['acquirer_data']['systan']
    assert resp['acquirer_data']['reference_number']

    assert_equal 'transaction approved', resp['acquirer_data']['response_message']
    assert_equal 'authorization', resp['acquirer_data']['transaction_type']

    # asert relations
    assert account.transactions.first   # account has trx
    assert terminal.transactions.first  # terminal has trx
    assert cashier.transactions.first   # cashier has trx


    # currency conversion tests
    conversion_currency = 'ANG'
    conversion_rate = 1.2345
    converted_amount = (amount * conversion_rate).to_i
    conversion_data = {converted_amount: converted_amount, conversion_rate: conversion_rate, conversion_currency: conversion_currency}

    ### invalid conversion when currency does not change
    card_data = {card_data: {amount: converted_amount, currency: CURRENCY_CODES[currency]}}
    post '/api/authorize', wallet_input.merge(conversion_data).merge(card_data).to_json
    resp = JSON.parse(last_response.body)
    assert last_response.unprocessable?
    assert_equal ["invalid card_data currency"], resp['currency']

    ### invalid conversion when amount does not change
    card_data = {card_data: {amount: amount, currency: CURRENCY_CODES[conversion_currency]}}
    post '/api/authorize', wallet_input.merge(conversion_data).merge(card_data).to_json
    resp = JSON.parse(last_response.body)
    assert last_response.unprocessable?
    assert_equal ["invalid card_data amount"], resp['amount']

    ### invalid conversion when amount is not converted properly
    card_data = {card_data: {amount: converted_amount + 1, currency: CURRENCY_CODES[conversion_currency]}}
    post '/api/authorize', wallet_input.merge(conversion_data).merge(card_data).to_json
    resp = JSON.parse(last_response.body)
    assert last_response.unprocessable?
    assert_equal ["invalid card_data amount"], resp['amount']

    ### valid conversion
    card_data = {card_data: {amount: converted_amount, currency: CURRENCY_CODES[conversion_currency]}}
    post '/api/authorize', wallet_input.merge(conversion_data).merge(card_data).to_json
    assert last_response.ok?

    ### inactive terminal
    terminal.update(active: false)
    post '/api/authorize', {access_token: terminal.access_token, digest: digest,
                            api_version: '1.0.0.', application_version: '1.0.0.',
                            amount: amount, currency: currency, systan: systan,
                            transaction_type: transaction_type, client_datetime: client_datetime,
                            cashier_pin: cashier_pin, cashier_id: cashier.id, card_data: {}}.to_json
    assert last_response.unprocessable?
    assert_equal 'unknown or disabled terminal', JSON.parse(last_response.body)['access_token'][0]
  end
end

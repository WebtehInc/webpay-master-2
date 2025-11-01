require_relative "../integration_helper"

class TestApiReverseTopUp < Test

  def test_api_reverse_top_up

    # merchant setup
    merchant = signup_user
    merchant_account  = generate_business_account merchant
    merchant_account.update credit_limit: 5000
    time = Time.now
    terminal = generate_terminal  account_id: merchant_account.id,
                                  opening_hours: time.hour - 1, opening_minutes: time.min - 2,
                                  closing_hours: time.hour + 1, closing_minutes: time.min + 2
    login_user
    cashier, cashier_pin = create_cashier terminal
    cashier.update(manager: true)


    # user setup
    user = signup_user(email: 'user@email.com')
    user_account = user.accounts.first
    currency = user_account.currency
    card_pin = '1234'
    card = generate_card user, pin_block: card_pin
    card_number = card.pan

    # trx topup
    systan = 123456
    client_datetime = Time.now.to_s

    # topup first time
    amount = starting_amount = 1000
    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, card_number, amount, currency, systan + 1)
    post '/api/top-up', { amount: amount, currency: currency, access_token: terminal.access_token, digest: digest, card_pin: card_pin,
                          systan: systan + 1, api_version: '1.0.0.', application_version: '1.0.0.', card_number: card_number,
                          client_datetime: client_datetime, cashier_pin: cashier_pin, cashier_id: cashier.id, payment_method: 'card', payment_method_type: 'debit'}.to_json
    assert last_response.ok?

    # topup second time, we will reverse this one instead previous one
    amount = amount + 1
    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, card_number, amount, currency, systan + 2)
    post '/api/top-up', { amount: amount, currency: currency, access_token: terminal.access_token, digest: digest, card_pin: card_pin,
                          systan: systan + 2, api_version: '1.0.0.', application_version: '1.0.0.', card_number: card_number,
                          client_datetime: client_datetime, cashier_pin: cashier_pin, cashier_id: cashier.id, payment_method: 'card', payment_method_type: 'debit'}.to_json
    assert last_response.ok?


    orig_trx = terminal.transactions_dataset.last

    # reversal digest
    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, orig_trx.id, systan + 2, amount)

    # no payload
    post '/api/reverse-top-up', {}.to_json
    assert last_response.unprocessable?
    assert_equal 10, JSON.parse(last_response.body).keys.size

    # invalid access_token
    post '/api/reverse-top-up', { access_token: 'any', digest: 'any', amount: amount, systan: systan + 2,
                                  api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: client_datetime,
                                  original_id: orig_trx.id, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json

    assert last_response.unprocessable?
    assert_equal 'unknown or disabled terminal', JSON.parse(last_response.body)['access_token'][0]

    # invalid digest
    post '/api/reverse-top-up', { access_token: terminal.access_token, digest: 'any', amount: amount, systan: systan + 2,
                                        api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: client_datetime,
                                        original_id: orig_trx.id, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['digest'][0]

    # invalid pin
    post '/api/reverse-top-up', { access_token: terminal.access_token, digest: 'any', amount: amount, systan: systan + 2,
                                        api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: client_datetime,
                                        original_id: orig_trx.id, cashier_pin: 'wrong', cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'invalid cashier pin', JSON.parse(last_response.body)['cashier_pin'][0]

    # inactive cashier
    cashier.update(active: false)
    post '/api/reverse-top-up', { access_token: terminal.access_token, digest: digest, amount: amount, systan: systan + 2,
                                        api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: client_datetime,
                                        original_id: orig_trx.id, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'invalid cashier pin', JSON.parse(last_response.body)['cashier_pin'][0]
    cashier.update(active: true)

    # reverse second topup
    post '/api/reverse-top-up', { access_token: terminal.access_token, digest: digest, amount: amount, systan: systan + 2,
                                  api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: client_datetime,
                                  original_id: orig_trx.id, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json

    assert last_response.ok?
    resp = JSON.parse(last_response.body)

    # merchant and user reversals
    rev = terminal.transactions_dataset.last
    user_rev = Transaction.last

    # response fields
    assert_equal rev.id, resp['id']
    assert_equal '1.0.0.', resp['api_version']
    assert_equal '1.0.0.', resp['application_version']
    assert_equal cashier.full_name, resp['cashier']
    assert_equal Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, orig_trx.id), resp['digest']

    # check merchant account
    assert_equal 0, merchant_account.reload.balance                 # fixed
    assert_equal starting_amount, merchant_account.exposure_amount  # first topup amount

    # check user account
    assert_equal starting_amount, user_account.reload.balance        # first topup amount

    # merchant reversal transaction attrs
    assert_equal amount, rev.amount                 # rev has paying amount
    assert_equal (systan + 2).to_s, rev.systan      # rev has systan
    assert_equal 'debit', rev.type                  # rev is debit
    assert_equal 'top_up_reversal_mpos', rev.transaction_type   # rev is bill_reversal_mpos
    assert_equal merchant_account.balance, rev.balance          # reflect balance in rev
    assert_equal '1.0.0.', rev.api_version
    assert_equal '1.0.0.', rev.application_version
    assert_equal client_datetime, rev.client_datetime.to_s
    assert_equal orig_trx.payment_method, rev.payment_method
    assert_equal orig_trx.payment_method_type, rev.payment_method_type
    assert_equal terminal.services_batch_number, rev.services_batch_number

    # check voided flag for original
    assert_equal true, orig_trx.reload.voided

    # user reversal transaction attrs
    user_rev_parent = user_rev.parent
    assert_equal true, user_rev_parent.voided
    assert_equal user_rev.amount, user_rev_parent.amount
    assert_equal 'debit', user_rev.type
    assert_equal 'top_up_reversal', user_rev.transaction_type

    # asert relations
    assert_equal 6, Transaction.count

    assert_equal 3, user_account.transactions_dataset.count
    assert_equal 3, user.transactions_dataset.count

    assert_equal 3, merchant_account.transactions_dataset.count
    assert_equal 3, terminal.transactions_dataset.count

    # topup third time
    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, card_number, amount, currency, systan + 3)
    post '/api/top-up', { amount: amount, currency: currency, access_token: terminal.access_token, digest: digest, card_pin: card_pin,
                          systan: systan + 3, api_version: '1.0.0.', application_version: '1.0.0.', card_number: card_number,
                          client_datetime: client_datetime, cashier_pin: cashier_pin, cashier_id: cashier.id, payment_method: 'card', payment_method_type: 'debit'}.to_json
    assert last_response.ok?
    assert_equal 8, Transaction.count                                                                 # we have one topup extra
    assert_equal merchant_account.exposure_amount + amount, merchant_account.reload.exposure_amount   # + amount
    assert_equal user_account.balance + amount, user_account.reload.balance                           # + amount
    assert_equal 0, merchant_account.balance                                                          # fixed

    # reverse last topup in previous batch fails
    terminal.services_batch_number = terminal.services_batch_number + 1; terminal.save
    last_trx = terminal.transactions_dataset.last
    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, last_trx.id, systan + 3, amount)
    post '/api/reverse-top-up', { access_token: terminal.access_token, digest: digest, amount: amount, systan: systan + 3,
                                  api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: client_datetime,
                                  original_id: last_trx.id, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?

    # check response - no changes
    assert_equal 'invalid reference', JSON.parse(last_response.body)['original_id'][0]
    assert_equal 8, Transaction.count                                                       # no change
    assert_equal merchant_account.exposure_amount, merchant_account.reload.exposure_amount  # no change
    assert_equal user_account.balance, user_account.reload.balance                          # no change
    assert_equal 0, merchant_account.balance                                                # no change

    # reverse last topup in curent batch is ok
    terminal.services_batch_number = terminal.services_batch_number - 1; terminal.save
    post '/api/reverse-top-up', { access_token: terminal.access_token, digest: digest, amount: amount, systan: systan + 3,
                                  api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: client_datetime,
                                  original_id: last_trx.id, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.ok?

    # check response - count and blance changed
    assert_equal 10, Transaction.count
    assert_equal 4, Transaction.where(voided: true).count                                             # we have one void extra
    assert_equal merchant_account.exposure_amount - amount, merchant_account.reload.exposure_amount   # - amount
    assert_equal user_account.balance - amount, user_account.reload.balance                           # - amount
    assert_equal 0, merchant_account.balance                                                          # fixed

    # double reverse last topup in curent batch fails
    post '/api/reverse-top-up', { access_token: terminal.access_token, digest: digest, amount: amount, systan: systan + 3,
                                  api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: client_datetime,
                                  original_id: last_trx.id, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?

    # check response  - no changes for double submit
    assert_equal 'invalid reference', JSON.parse(last_response.body)['original_id'][0]
    assert_equal 10, Transaction.count                                                      # no change
    assert_equal 4, Transaction.where(voided: true).count                                   # no change
    assert_equal merchant_account.exposure_amount, merchant_account.reload.exposure_amount  # no change
    assert_equal user_account.balance, user_account.reload.balance                          # no change
    assert_equal 0, merchant_account.balance                                                # no change
  end

end

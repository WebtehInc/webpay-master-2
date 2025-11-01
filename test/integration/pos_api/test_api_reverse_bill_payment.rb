require_relative "../integration_helper"

class TestApiReverseBillPayment < Test

  def test_api_reverse_bill_payment
    systan          = 123
    systan_2        = 123456
    client_datetime = Time.now.to_s

    user      = signup_user
    account   = generate_business_account user
    account.update credit_limit: 5000

    operator  = generate_operator type: 'bill'
    customer  = generate_customer
    time      = Time.now
    terminal  = generate_terminal account_id: account.id,
                                  opening_hours: time.hour - 1, opening_minutes: time.min - 2,
                                  closing_hours: time.hour + 1, closing_minutes: time.min + 2

    # create cashier
    login_user
    cashier, cashier_pin = create_cashier terminal
    cashier.update(manager: true)

    # pay first bill
    amount = first_amount = 1000
    pay_bill terminal, 'card', 'debit', amount, cashier_pin, operator, customer, systan, cashier.id

    # pay second bill
    amount =  amount + 1
    pay_bill terminal, 'card', 'debit', amount, cashier_pin, operator, customer, systan_2, cashier.id

    orig_trx = Transaction.last

    # reversal digest
    digest    = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, orig_trx.id, systan, amount)
    digest_2  = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, orig_trx.id, systan_2, amount)

    # no payload
    post '/api/reverse-bill-payment', {}.to_json
    assert last_response.unprocessable?
    assert_equal 10, JSON.parse(last_response.body).keys.size

    # invalid access_token
    post '/api/reverse-bill-payment', { access_token: 'any', digest: 'any', amount: amount, systan: systan,
                                        api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: client_datetime,
                                        original_id: orig_trx.id, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json

    assert last_response.unprocessable?
    assert_equal 'unknown or disabled terminal', JSON.parse(last_response.body)['access_token'][0]

    # invalid digest
    post '/api/reverse-bill-payment', { access_token: terminal.access_token, digest: 'any', amount: amount, systan: systan,
                                        api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: client_datetime,
                                        original_id: orig_trx.id, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['digest'][0]

    # invalid pin
    post '/api/reverse-bill-payment', { access_token: terminal.access_token, digest: 'any', amount: amount, systan: systan,
                                        api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: client_datetime,
                                        original_id: orig_trx.id, cashier_pin: 'wrong', cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'invalid cashier pin', JSON.parse(last_response.body)['cashier_pin'][0]

    # inactive cashier
    cashier.update(active: false)
    post '/api/reverse-bill-payment', { access_token: terminal.access_token, digest: digest, amount: amount, systan: systan,
                                        api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: client_datetime,
                                        original_id: orig_trx.id, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'invalid cashier pin', JSON.parse(last_response.body)['cashier_pin'][0]
    cashier.update(active: true)

    # reverse now
    post '/api/reverse-bill-payment', { access_token: terminal.access_token, digest: digest_2, amount: amount, systan: systan_2,
                                        api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: client_datetime,
                                        original_id: orig_trx.id, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    rev = Transaction.last

    # response fields
    assert_equal rev.id, resp['id']
    assert_equal '1.0.0.', resp['api_version']
    assert_equal '1.0.0.', resp['application_version']
    assert_equal cashier.full_name, resp['cashier']

    # original balances
    old_customer = customer.values.dup
    old_account = account.values.dup

    customer.reload
    account.reload

    # check customer balance
    assert_equal old_customer[:balance] + first_amount, customer.balance   # first amount

    # check merchant account
    assert_equal first_amount, account.exposure_amount  # first amount
    assert_equal old_account[:balance], account.balance # not changed

    # transactions attrs
    assert_equal amount, rev.amount             # rev has paying amount
    assert_equal systan_2.to_s, rev.systan      # rev has systan
    assert_equal 'debit', rev.type              # rev is debit
    assert_equal 'bill_reversal_mpos', rev.transaction_type   # rev is bill_reversal_mpos
    assert_equal account.balance, rev.balance                 # reflect balance in rev
    assert_equal '1.0.0.', rev.api_version
    assert_equal '1.0.0.', rev.application_version
    assert_equal client_datetime, rev.client_datetime.to_s
    assert_equal orig_trx.payment_method, rev.payment_method
    assert_equal orig_trx.payment_method_type, rev.payment_method_type
    assert_equal terminal.services_batch_number, rev.services_batch_number
    assert_equal operator.code, rev.operator_code     # operator code
    assert_equal customer.number, rev.customer_number # customer_number

    # check voided flag for original
    assert_equal true, orig_trx.reload.voided

    # assert relations
    assert_equal 3, Transaction.count
    assert_equal 1, Transaction.where(voided: true).count

    assert_equal 3, account.transactions_dataset.count
    assert_equal 3, terminal.transactions_dataset.count

    # check response digest
    assert_equal Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, orig_trx.id), resp['digest']

    # pay 3rd bill
    systan_3  = 123456789
    pay_bill terminal, 'card', 'debit', amount, cashier_pin, operator, customer, systan_3, cashier.id
    last_trx  = Transaction.last
    digest_3  = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, last_trx.id, systan_3, amount)

    # check response - count and blance changed
    assert_equal 4, Transaction.count                                             # one extra bill
    assert_equal customer.balance + amount, customer.reload.balance               # + amount
    assert_equal account.exposure_amount + amount, account.reload.exposure_amount # + amount
    assert_equal 0, account.balance                                               # not changed


    # reverse 3rd from old batch fails
    terminal.services_batch_number = terminal.services_batch_number - 1; terminal.save
    post '/api/reverse-bill-payment', { access_token: terminal.access_token, digest: digest_3, amount: amount, systan: systan_3,
                                        api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: client_datetime,
                                        original_id: last_trx.id, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?

    # check response - no change
    assert_equal 'invalid reference', JSON.parse(last_response.body)['original_id'][0]
    assert_equal 4, Transaction.count                                    # no void
    assert_equal customer.balance, customer.reload.balance               # not changed
    assert_equal account.exposure_amount, account.reload.exposure_amount # not changed
    assert_equal 0, account.balance                                      # not changed

    # reverse 3rd bill is ok for current batch
    terminal.services_batch_number = terminal.services_batch_number + 1; terminal.save
    post '/api/reverse-bill-payment', { access_token: terminal.access_token, digest: digest_3, amount: amount, systan: systan_3,
                                        api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: client_datetime,
                                        original_id: last_trx.id, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.ok?

    # check response - count and blance changed
    assert_equal 5, Transaction.count                                             # one extra void
    assert_equal customer.balance - amount, customer.reload.balance               # - amount
    assert_equal account.exposure_amount - amount, account.reload.exposure_amount # - amount
    assert_equal 0, account.balance

    # double reverse last topup in curent batch fails
    terminal.services_batch_number = terminal.services_batch_number + 1; terminal.save
    post '/api/reverse-bill-payment', { access_token: terminal.access_token, digest: digest_3, amount: amount, systan: systan_3,
                                        api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: client_datetime,
                                        original_id: last_trx.id, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?

    # check response - no change
    assert_equal 'invalid reference', JSON.parse(last_response.body)['original_id'][0]
    assert_equal 5, Transaction.count                                    # no void
    assert_equal customer.balance, customer.reload.balance               # not changed
    assert_equal account.exposure_amount, account.reload.exposure_amount # not changed
    assert_equal 0, account.balance                                      # not changed
  end

end

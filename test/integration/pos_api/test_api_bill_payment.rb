require_relative "../integration_helper"

class TestApiBillPayment < Test
  def test_api_bill_payment
    credit_limit = 600
    max_amount = 500
    min_amount = 10
    paying_amount = max_amount - 1
    systan = "00001234"
    client_datetime = Time.now.to_s

    user = signup_user
    account = generate_business_account user
    account.update credit_limit: credit_limit, max_amount: max_amount, min_amount: min_amount
    operator = generate_operator type: "bill"
    customer = generate_customer
    terminal = generate_terminal account_id: account.id

    # create cashier
    login_user
    cashier, cashier_pin = create_cashier terminal

    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, operator.code, customer.number, paying_amount, customer.currency + systan)

    # no payload
    post "/api/bill-payment", {}.to_json
    assert last_response.unprocessable?
    assert_equal 14, JSON.parse(last_response.body).keys.size

    # invalid access_token
    post "/api/bill-payment", { operator_code: operator.code, customer_number: customer.number, amount: paying_amount,
                                currency: customer.currency, access_token: "any", digest: "any",
                                systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                                client_datetime: client_datetime, payment_method: "cash" }.to_json
    assert last_response.unprocessable?
    assert_equal "unknown or disabled terminal", JSON.parse(last_response.body)["access_token"][0]

    # invalid digest
    post "/api/bill-payment", { operator_code: operator.code, customer_number: customer.number, amount: paying_amount,
                                currency: customer.currency, access_token: terminal.access_token, digest: "invalid",
                                systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                                client_datetime: client_datetime, payment_method: "cash" }.to_json
    assert last_response.unprocessable?
    assert_equal "is invalid", JSON.parse(last_response.body)["digest"][0]

    # invalid pin
    post "/api/bill-payment", { operator_code: operator.code, customer_number: customer.number, amount: paying_amount,
                                currency: customer.currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                                client_datetime: client_datetime, payment_method: "cash", cashier_pin: "wrong", cashier_id: cashier.id }.to_json
    assert last_response.unprocessable?
    assert_equal "invalid cashier pin", JSON.parse(last_response.body)["cashier_pin"][0]

    # below operator min. amount
    under_limit_amount = operator.min_amount - 1
    under_limit_digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, operator.code, customer.number, under_limit_amount, customer.currency, systan)
    post "/api/bill-payment", { operator_code: operator.code, customer_number: customer.number, amount: under_limit_amount,
                                currency: customer.currency, access_token: terminal.access_token, digest: under_limit_digest,
                                systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                                client_datetime: client_datetime, payment_method: "cash", cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.unprocessable?
    assert_equal "under operator minimum amount", JSON.parse(last_response.body)["amount"][0]

    # inactive cashier
    cashier.update(active: false)
    post "/api/bill-payment", { operator_code: operator.code, customer_number: customer.number, amount: paying_amount,
                                currency: customer.currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                                client_datetime: client_datetime, payment_method: "cash", cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.unprocessable?
    assert_equal "invalid cashier pin", JSON.parse(last_response.body)["cashier_pin"][0]
    cashier.update(active: true)

    # missmatch payment_method_type
    post "/api/bill-payment", { operator_code: operator.code, customer_number: customer.number, amount: paying_amount,
                                currency: customer.currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                                client_datetime: client_datetime, payment_method: "card",
                                payment_method_type: MPOS_CHECK_PAYMENT_METHOD_TYPES[0][:payment_method_type], cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.unprocessable?
    assert_equal "payment type mismatch", JSON.parse(last_response.body)["payment_method"][0]

    # invalid payment_method_type
    post "/api/bill-payment", { operator_code: operator.code, customer_number: customer.number, amount: paying_amount,
                                currency: customer.currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                                client_datetime: client_datetime, payment_method: "card", payment_method_type: "unknown",
                                cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.unprocessable?
    assert JSON.parse(last_response.body)["payment_method_type"]

    # after hours
    post "/api/bill-payment", { operator_code: operator.code, customer_number: customer.number, amount: paying_amount,
                                currency: customer.currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                                client_datetime: client_datetime, payment_method: "card", payment_method_type: "debit",
                                cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.unprocessable?
    assert_equal "after hours, store is closed", JSON.parse(last_response.body)["access_token"][0]

    # pay now
    cashier.update(manager: true) # promote cashier to manager
    time = Time.now
    terminal.update(opening_hours: time.hour - 1, opening_minutes: time.min - 1, closing_hours: time.hour + 1, closing_minutes: time.min + 1) # open store
    payload = { operator_code: operator.code, customer_number: customer.number, amount: paying_amount,
                currency: customer.currency, access_token: terminal.access_token, digest: digest,
                systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                client_datetime: client_datetime, payment_method: "card", payment_method_type: "debit",
                cashier_pin: cashier_pin, cashier_id: cashier.id }

    # unknown customer
    post "/api/bill-payment", payload.merge(customer_number: "1234567890").to_json
    assert last_response.unprocessable?
    assert_equal ({ "digest" => ["is invalid"], "customer_number" => ["unknown account"] }), JSON.parse(last_response.body)

    # inactive customer
    customer.update(active: false)
    post "/api/bill-payment", payload.to_json
    assert last_response.unprocessable?
    assert_equal ({ "customer_number" => ["account is disabled"] }), JSON.parse(last_response.body)
    customer.update(active: true)

    # active customer
    post "/api/bill-payment", payload.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    trx = Transaction.first

    # response fields
    assert_equal trx.id, resp["id"]
    assert_equal "1.0.0.", resp["api_version"]
    assert_equal "1.0.0.", resp["application_version"]
    assert_equal cashier.full_name, resp["cashier"]

    # check balances for customer
    assert_equal customer.balance + paying_amount, customer.reload.balance  # credited balance

    # check merchant account
    account_with_old_values = account.values.dup
    account.reload
    assert_equal paying_amount, account.exposure_amount             # updated exposure for account
    assert_equal account_with_old_values[:balance], account.balance # balance is unchanged

    # transactions attrs
    assert_equal paying_amount, trx.amount          # trx has paying amount
    assert_equal systan, trx.systan                 # trx has systan
    assert_equal "credit", trx.type                 # trx is credit
    assert_equal "bill_mpos", trx.transaction_type  # trx is bill_mpos
    assert_equal account.balance, trx.balance       # reflect balance in trx
    assert_equal "1.0.0.", trx.api_version
    assert_equal "1.0.0.", trx.application_version
    assert_equal client_datetime, trx.client_datetime.to_s
    assert_equal "card", trx.payment_method
    assert_equal "debit", trx.payment_method_type
    assert_equal terminal.services_batch_number, trx.services_batch_number # batch number
    assert_equal operator.code, trx.operator_code     # operator code
    assert_equal customer.number, trx.customer_number # customer_number

    # asert relations
    assert account.transactions.first   # account has trx
    assert terminal.transactions.first  # terminal has trx
    assert cashier.transactions.first   # cashier has trx

    # check response digest
    assert_equal Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, resp["id"]), resp["digest"]

    # retry to get cached response
    post "/api/bill-payment/retry", payload.to_json
    assert last_response.ok?
    assert_equal resp, JSON.parse(last_response.body)
    assert_equal 1, Transaction.count

    # hit max amount limit
    account.update credit_limit: credit_limit
    paying_amount = max_amount + 1
    post "/api/bill-payment", { operator_code: operator.code, customer_number: customer.number, amount: paying_amount,
                                currency: customer.currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                                client_datetime: client_datetime, payment_method: "cash",
                                payment_method_type: "debit", cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.unprocessable?
    assert_equal "over maximum amount", JSON.parse(last_response.body)["amount"][0]

    # hit min amount limit
    paying_amount = min_amount - 1
    post "/api/bill-payment", { operator_code: operator.code, customer_number: customer.number, amount: paying_amount,
                                currency: customer.currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                                client_datetime: client_datetime, payment_method: "cash",
                                payment_method_type: "debit", cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.unprocessable?
    assert_equal "under minimum amount", JSON.parse(last_response.body)["amount"][0]

    # hit credit limit
    paying_amount = max_amount - 1
    post "/api/bill-payment", { operator_code: operator.code, customer_number: customer.number, amount: paying_amount,
                                currency: customer.currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                                client_datetime: client_datetime, payment_method: "cash",
                                payment_method_type: "debit", cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.unprocessable?
    assert_equal "credit limit exceeded", JSON.parse(last_response.body)["amount"][0]

    # pay for inactive terminal
    terminal.update(active: false)
    post "/api/bill-payment", { operator_code: operator.code, customer_number: customer.number, amount: paying_amount,
                                currency: customer.currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                                client_datetime: client_datetime, payment_method: "cash",
                                payment_method_type: "debit", cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.unprocessable?
    assert_equal "unknown or disabled terminal", JSON.parse(last_response.body)["access_token"][0]

    # retry to get new transaction
    Transaction.dataset.delete
    MemoryStore.flush_all
    terminal.update(active: true)
    account.update credit_limit: 2 * credit_limit
    post "/api/bill-payment/retry", payload.to_json
    assert last_response.ok?
    assert_equal 1, Transaction.count
  end
end

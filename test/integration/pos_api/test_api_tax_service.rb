require_relative "../integration_helper"
require "webmock"
include WebMock::API

UUID = "37281025-32da-48fb-bbac-abaeb6be0e88" # SecureRandom.uuid()

module SecureRandom
  def self.uuid()
    UUID
  end
end

class TestApiTaxServiceHandler < Test
  CONFIRM_REFERENCE_URL = "/api/services/tax/confirm-reference"
  PAYMENT_URL = "/api/services/tax/payment"

  def setup
    super
    VCR.eject_cassette
    VCR.turn_off!
    WebMock.enable!
  end

  def test_payment_flow
    max_amount = 500
    min_amount = 10
    credit_limit = max_amount * 3
    systan = "00001234"
    client_datetime = Time.now.to_s

    user = signup_user
    account = generate_business_account user
    account.update credit_limit: credit_limit, max_amount: max_amount, min_amount: min_amount
    terminal = generate_terminal account_id: account.id, opening_hours: 0, opening_minutes: 0, closing_hours: 23, closing_minutes: 59

    # curgas service
    operator = generate_operator name: "Tax", type: "api", code: "tx"

    # create cashier
    login_user
    cashier, cashier_pin = create_cashier terminal

    # service data
    platform_id = UUID
    request_time = "2025-03-09 15:53:46 -0400" # Time.now.to_s
    payment_ref = "31201810010471"
    amount = 100

    # from confirm_reference response
    reference_id = "252B6FE6-10FD-EF11-B879-549F350A9EA9"
    customer_id = "171476748"
    payment_period = "2018-13"
    tax_type = "AFS"

    # from payment response
    payment_id = "27C2B802-11FD-EF11-B879-549F350A9EA9"

    MemoryStore.delete(TaxService.confirm_reference_cache_key(platform_id))

    ##### confirm reference

    ### no payload
    post CONFIRM_REFERENCE_URL, {}.to_json
    assert last_response.unprocessable?
    assert_equal 9, JSON.parse(last_response.body).keys.size

    ### payload ok

    ## valid service call

    confirm_reference_mock = {
      "responseTime" => "2025-03-09 15:00:23",
      "platformId" => platform_id,
      "referenceId" => reference_id,
      "customerName" => "XTPUTCP YXKGI VICRFETLEZ",
      "paymentType" => "Assessment/Aanslag",
      "paymentRef" => payment_ref,
      "responseDescription" => "OK",
      "customerId" => customer_id,
      "responseValue" => "200",
      "paymentPeriod" => payment_period,
      "taxType" => tax_type,
    }

    url = TaxService::HOST_URL + TaxService::CONFIRM_REFERENCE_PATH
    headers = { "X-Api-Key" => TaxService::API_KEY, "Content-Type" => "application/json" }
    stub_request(:post, url)
      .with(headers: headers)
      .to_return(status: 200, body: confirm_reference_mock.to_json, headers: {})

    digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + payment_ref)
    payload_common = { operator_code: operator.code, access_token: terminal.access_token, digest: digest,
                       systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                       client_datetime: client_datetime, cashier_pin: cashier_pin, cashier_id: cashier.id }
    payload = payload_common.merge({ payment_ref: payment_ref })

    # call
    post CONFIRM_REFERENCE_URL, payload.to_json

    # verify response
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal resp["data"], confirm_reference_mock

    # verify cache
    cached_confirm_reference = MemoryStore.get(TaxService.confirm_reference_cache_key(platform_id))
    assert_equal cached_confirm_reference, confirm_reference_mock

    ## service call returns error
    confirm_reference_mock.merge!("responseDescription" => "Bad Request")
    stub_request(:post, url)
      .with(headers: headers)
      .to_return(status: 200, body: confirm_reference_mock.to_json, headers: {})

    # call
    post CONFIRM_REFERENCE_URL, payload.to_json

    # verify response
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal resp["responseDescription"], "Bad Request"

    ## service call returns http error
    stub_request(:post, url)
      .with(headers: headers)
      .to_return(status: 500, body: "500 server error", headers: {})

    # call
    post CONFIRM_REFERENCE_URL, payload.to_json

    # verify response
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal resp, { "http_error" => { "body" => "500 server error", "status" => 500 } }

    ##### payment

    ### no payload
    post PAYMENT_URL, {}.to_json
    assert last_response.unprocessable?
    assert_equal 13, JSON.parse(last_response.body).keys.size

    ### payload ok

    payment_mock = {
      "responseDescription" => "OK",
      "paymentId" => payment_id,
      "responseTime" => "2025-03-09 14:04:58.373",
      "responseValue" => "200",
      "platformId" => platform_id,
      "paymentAmount" => amount.to_s,
      "paymentRef" => payment_ref,
    }

    url = TaxService::HOST_URL + TaxService::PAYMENT_PATH
    stub_request(:post, url)
      .with(headers: headers)
      .to_return(status: 200, body: payment_mock.to_json, headers: {})

    payload_common.merge!(payment_method: "card", payment_method_type: "debit")
    digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + amount.to_s + operator.currency + platform_id.to_s)
    payload = payload_common.merge({ digest: digest, platform_id: platform_id, amount: amount, currency: operator.currency })

    # call
    post PAYMENT_URL, payload.to_json

    # verify response
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal resp["data"], payment_mock

    # verify tx
    trx = Transaction.first
    assert_equal trx.type, "credit"
    assert_equal trx.amount, amount
    assert_equal trx.currency, operator.currency
    assert_equal trx.transaction_type, "service_mpos"
    assert_equal trx.reference_number, platform_id
    assert_equal trx.status, "approved"
    assert_equal trx.customer_number, customer_id
    assert_equal trx.operator_code, operator.code
    assert_equal trx.approval_code, payment_id

    # asert relations
    assert account.transactions.first   # account has trx
    assert terminal.transactions.first  # terminal has trx
    assert cashier.transactions.first   # cashier has trx

    ### retry
    post "#{PAYMENT_URL}/retry", payload.to_json
    assert last_response.ok?
    assert_equal JSON.parse(last_response.body), resp
    assert_equal Transaction.first, Transaction.last

    ### service call returns error
    payment_mock.merge!("responseDescription" => "Bad Request")
    stub_request(:post, url)
      .with(headers: headers)
      .to_return(status: 200, body: payment_mock.to_json, headers: {})

    # call
    post PAYMENT_URL, payload.to_json

    # verify response
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal resp["responseDescription"], "Bad Request"

    #### service call returns http error
    stub_request(:post, url)
      .with(headers: headers)
      .to_return(status: 500, body: "500 server error", headers: {})

    # call
    post PAYMENT_URL, payload.to_json

    # verify response
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal resp, { "http_error" => { "body" => "500 server error", "status" => 500 } }
  end
end

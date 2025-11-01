require_relative "../integration_helper"
require "webmock"
include WebMock::API

class TestApiPagatinuServiceHandler < Test
  RECHARGE_URL = "/api/services/pagatinu/recharge"

  def setup
    super
    VCR.eject_cassette
    VCR.turn_off!
    WebMock.enable!
  end

  def test_recharge
    max_amount = 500
    min_amount = 10
    credit_limit = max_amount * 3
    systan = "00001234"
    client_datetime = Time.now.to_s

    user = signup_user
    account = generate_business_account user
    account.update credit_limit: credit_limit, max_amount: max_amount, min_amount: min_amount
    terminal = generate_terminal account_id: account.id, opening_hours: 0, opening_minutes: 0, closing_hours: 23, closing_minutes: 59

    # pagatinu service
    operator = generate_operator name: "Pagatinu", type: "api", code: "pg"

    # create cashier
    login_user
    cashier, cashier_pin = create_cashier terminal

    # service data
    customer_id = "customer-id"
    amount = 100

    ### no payload
    post RECHARGE_URL, {}.to_json
    puts JSON.parse(last_response.body)
    assert last_response.unprocessable?
    assert_equal 13, JSON.parse(last_response.body).keys.size

    #### with ValidateOnly = false
    ### payload ok
    digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + customer_id.to_s + amount.to_s)
    payload_common = { operator_code: operator.code, access_token: terminal.access_token, digest: digest,
                       systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                       client_datetime: client_datetime, cashier_pin: cashier_pin, cashier_id: cashier.id,
                       payment_method: "card", payment_method_type: "debit", validate_only: false }
    payload = payload_common.merge({ customer_id: customer_id, amount: amount })

    # service url
    # url = PagatinuService::HOST_URL + PagatinuService::RECHARGE_PATH
    # url = "#{url}?CustomerId=#{customer_id}&PaymentTransID=internal&Amount=#{amount}&ChannelId=External&PaymentProvider=Pagafasil"

    ## service call returned http error
    stub_request(:any, /recharge/).to_return(status: 500, body: "500 server error")

    # call
    post RECHARGE_URL, payload.to_json

    # verify response
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal resp, { "http_error" => { "body" => "500 server error", "status" => 500 } }

    ## service call returned error
    body_mock = {
      "name": "recharge",
      "param": [
        {
          "pname": "ErrorCode",
          "pval": "1006",
        },
        {
          "pname": "ErrorText",
          "pval": "PaymentTransID already used",
        },
        {
          "pname": "ErrorType",
          "pval": "Recharge",
        },
      ],
    }
    stub_request(:any, /recharge/).to_return(status: 200, body: body_mock.to_json)

    # call
    post RECHARGE_URL, payload.to_json

    # verify response
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal resp, { "recharge" => "PaymentTransID already used (1006)" }

    ## service call returned valid respopnse
    approval_code = "G20000000307"
    body_mock = {
      "name": "recharge",
      "param": [
        {
          "pname": "Account",
          "pval": "180000",
        },
        {
          "pname": "Delta",
          "pval": "11000",
        },
        {
          "pname": "PaymentTransID",
          "pval": "28-11-001",
        },
        {
          "pname": "OwnTransID",
          "pval": approval_code,
        },
        {
          "pname": "Contract.Address",
          "pval": "Some address",
        },
      ],
    }
    stub_request(:any, /recharge/).to_return(status: 200, body: body_mock.to_json)

    # call
    post RECHARGE_URL, payload.to_json

    # verify response
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal resp["data"], { "Account" => "180000", "Delta" => "11000", "PaymentTransID" => "28-11-001", "OwnTransID" => approval_code, "Contract.Address" => "Some address" }

    # verify tx
    trx = Transaction.first
    assert_equal resp["id"], trx.id
    assert_equal trx.type, "credit"
    assert_equal trx.amount, amount
    assert_equal trx.currency, operator.currency
    assert_equal trx.transaction_type, "service_mpos"
    assert_equal trx.status, "approved"
    assert_equal trx.customer_number, customer_id
    assert_equal trx.operator_code, operator.code
    assert_equal trx.approval_code, approval_code
    # assert_equal trx.reference_number, internal

    # asert relations
    assert account.transactions.first   # account has trx
    assert terminal.transactions.first  # terminal has trx
    assert cashier.transactions.first   # cashier has trx

    ### retry
    post "#{RECHARGE_URL}/retry", payload.to_json
    assert last_response.ok?
    assert_equal JSON.parse(last_response.body), resp
    assert_equal Transaction.first, Transaction.last

    #### with ValidateOnly = true
    body_mock = {
      "name": "recharge",
      "param": [
        {
          "pname": "Account",
          "pval": "180000",
        },
        {
          "pname": "PaymentTransID",
          "pval": "28-11-001",
        },
        {
          "pname": "Contract.Address",
          "pval": "Some address",
        },
      ],
    }
    stub_request(:any, /recharge/).to_return(status: 200, body: body_mock.to_json)

    # call
    post RECHARGE_URL, payload.merge(validate_only: true).to_json

    # verify response
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal resp.has_key?("id"), false
    assert_equal resp["data"], { "Account" => "180000", "PaymentTransID" => "28-11-001", "Contract.Address" => "Some address" }
  end
end

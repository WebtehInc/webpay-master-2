require_relative "../integration_helper"
require_relative "../../fixtures/pagatinu_rest"

require "webmock"
include WebMock::API

class TestApiPagatinuRestServiceHandler < Test
  DATETIME_FORMAT = "%Y%m%d%H%M%S"
  CREDIT_URL = "/api/services/pagatinu-rest/credit"
  TRIAL_URL = "/api/services/pagatinu-rest/trial"

  def setup
    super
    VCR.eject_cassette
    VCR.turn_off!
    WebMock.enable!
  end

  def test_credit_flow
    max_amount = 500
    min_amount = 10
    credit_limit = max_amount * 3

    user = signup_user
    account = generate_business_account user
    account.update credit_limit: credit_limit, max_amount: max_amount, min_amount: min_amount
    terminal = generate_terminal account_id: account.id, opening_hours: 0, opening_minutes: 0, closing_hours: 23, closing_minutes: 59

    # pagatinu service
    operator = generate_operator name: "Pagatinu REST", type: "api", code: "pg-rest"

    # create cashier
    login_user
    cashier, cashier_pin = create_cashier terminal

    # wp input
    client_datetime = Time.now.to_s

    # service input
    ms_no = "123456"
    stan = systan = "123456789" # wp
    purchase_value = amount = 100 # wp
    date_time = Time.now.strftime(DATETIME_FORMAT)

    ### no payload
    post CREDIT_URL, {}.to_json
    assert last_response.unprocessable?
    assert_equal 13, JSON.parse(last_response.body).keys.size

    ### payload ok
    stan_in_pagatinu_payload = terminal.id * 10000 + stan.to_i % 10000
    expected_pagatinu_payload = {
      "terminalID" => "0000000000002",
      "msNo" => ms_no,
      "stan" => stan_in_pagatinu_payload,
      "dateTime" => date_time,
      "purchaseValue" => purchase_value / 100.0,
      "operatorName" => "pagafasil",
      "password" => "pagafasil",
    }.to_json
    body_mock = VALID_BODY_MOCK

    url = PagatinuRestService::HOST_URL + PagatinuRestService::CREDIT_PATH
    stub_request(:post, url).with(body: expected_pagatinu_payload, headers: { "X-Api-Key" => PagatinuRestService::API_KEY }).to_return(status: 200, body: body_mock.to_json, headers: {})

    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, ms_no, amount, systan)

    payload_common = { operator_code: operator.code, access_token: terminal.access_token, digest: digest,
                       api_version: "1.0.0.", application_version: "1.0.0.",
                       client_datetime: client_datetime, cashier_pin: cashier_pin, cashier_id: cashier.id }
    payload_common.merge!(payment_method: "card", payment_method_type: "debit")

    payload = payload_common.merge({ ms_no: ms_no, date_time: date_time, amount: amount, systan: systan })

    # call
    post CREDIT_URL, payload.to_json

    # verify response
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    data = resp["data"]
    assert_equal data, {
      "customer_name" => "AGHA LIMITED",
      "datetime" => "2024-05-13T08:20:47.1317707-04:00",
      "terminal_id" => "0000000000002",
      "meter_number" => "04257670895",
      "receipt_number" => "10071872",
      "account_number" => "3101149376",
      "tariff" => "DOMESTIC ELECTRICITY",
      "energy_value" => "132.7",
      "energy2_value" => nil,
      "energy3_value" => nil,
      "energy_si_unit" => "kWh",
      "energy2_si_unit" => nil,
      "energy3_si_unit" => nil,
      "amount_paid_currency" => "ANG",
      "amount_paid_value" => "100",
      "token1" => "04257670895000001327",
      "token2" => nil,
      "token3" => nil,
      "customer_number" => "04257670895",
      "transaction_id" => "1230000001",
    }

    # verify tx
    trx = Transaction.first
    assert_equal trx.type, "credit"
    assert_equal trx.amount, amount
    assert_equal trx.currency, operator.currency
    assert_equal trx.transaction_type, "service_mpos"
    assert_equal trx.status, "approved"
    assert_equal trx.operator_code, operator.code
    assert_equal trx.reference_number, data["receipt_number"]
    assert_equal trx.customer_number, data["customer_number"][0]

    # asert relations
    assert account.transactions.first   # account has trx
    assert terminal.transactions.first  # terminal has trx
    assert cashier.transactions.first   # cashier has trx
  end

  def test_trial_flow
    max_amount = 500
    min_amount = 10
    credit_limit = max_amount * 3

    user = signup_user
    account = generate_business_account user
    account.update credit_limit: credit_limit, max_amount: max_amount, min_amount: min_amount
    terminal = generate_terminal account_id: account.id, opening_hours: 0, opening_minutes: 0, closing_hours: 23, closing_minutes: 59

    # pagatinu service
    operator = generate_operator name: "Pagatinu REST", type: "api", code: "pg-rest"

    # create cashier
    login_user
    cashier, cashier_pin = create_cashier terminal

    # wp input
    client_datetime = Time.now.to_s

    # service input
    ms_no = "123456"
    stan = systan = "123456789" # wp
    purchase_value = amount = 100 # wp
    date_time = Time.now.strftime(DATETIME_FORMAT)

    ### no payload
    post TRIAL_URL, {}.to_json
    assert last_response.unprocessable?
    assert_equal 9, JSON.parse(last_response.body).keys.size

    ### payload ok
    stan_in_pagatinu_payload = terminal.id * 10000 + stan.to_i % 10000
    expected_pagatinu_payload = {
      "terminalID" => "0000000000002",
      "msNo" => ms_no,
      "stan" => stan_in_pagatinu_payload,
      "dateTime" => date_time,
      "amount" => purchase_value / 100.0,
      "operatorName" => "pagafasil",
      "password" => "pagafasil",
    }.to_json
    body_mock = { "msg" => "ok" }

    url = PagatinuRestService::HOST_URL + PagatinuRestService::TRIAL_PATH
    stub_request(:post, url).with(body: expected_pagatinu_payload, headers: { "X-Api-Key" => PagatinuRestService::API_KEY }).to_return(status: 200, body: body_mock.to_json, headers: {})

    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, ms_no, amount, systan)

    payload_common = { operator_code: operator.code, access_token: terminal.access_token, digest: digest,
                       api_version: "1.0.0.", application_version: "1.0.0.",
                       client_datetime: client_datetime }
    payload = payload_common.merge({ ms_no: ms_no, date_time: date_time, amount: amount, systan: systan })

    # call
    post TRIAL_URL, payload.to_json

    # verify response
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    data = resp["data"]
    assert_equal data, body_mock
  end
end

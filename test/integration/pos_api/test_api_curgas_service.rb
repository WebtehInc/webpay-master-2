require_relative "../integration_helper"
require "webmock"
include WebMock::API

class TestApiCurgasServiceHandler < Test
  CHECK_ORDER_URL = "/api/services/curgas/check-order"
  NEW_ORDER_URL = "/api/services/curgas/new-order"

  def setup
    super
    VCR.eject_cassette
    VCR.turn_off!
    WebMock.enable!
  end

  def test_new_order_flow
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
    operator = generate_operator name: "Curgas", type: "api", code: "cg"

    # create cashier
    login_user
    cashier, cashier_pin = create_cashier terminal

    # service data
    cods_identity = "456"
    curgas_id = "123"
    quantity = 10
    rush = 1
    amount = 1000

    MemoryStore.delete(CurgasService::TOKEN_CACHE_KEY)
    MemoryStore.delete(CurgasService.order_cache_key(cods_identity))

    # login to service
    token_mock = "token"
    url = CurgasService::HOST_URL + CurgasService::LOGIN_PATH
    payload = { "username": CurgasService::USERNAME, "password": CurgasService::PASSWORD }.to_json
    stub_request(:post, url).with(body: payload).to_return(status: 200, body: token_mock, headers: {})
    CurgasService.login()

    ##### check order

    ### no payload
    post CHECK_ORDER_URL, {}.to_json
    assert last_response.unprocessable?
    assert_equal 11, JSON.parse(last_response.body).keys.size

    ### payload ok

    ## valid service call
    # mock http response
    body_mock = [
      {
        "curgas_id" => curgas_id,
        "quantity_request" => quantity,
        "rush_delivery" => rush,
        "can_order" => "Y",
        "total_order" => amount,
        "cods_identity" => cods_identity,
        "error" => 0,
      },
    ]
    url = CurgasService::HOST_URL + CurgasService.check_order_path(curgas_id, quantity, rush)
    stub_request(:get, url).with(headers: { "Authorization" => "Bearer #{token_mock}" }).to_return(status: 200, body: body_mock.to_json, headers: {})

    digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + curgas_id.to_s + quantity.to_s + rush.to_s)
    payload_common = { operator_code: operator.code, access_token: terminal.access_token, digest: digest,
                       systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                       client_datetime: client_datetime, cashier_pin: cashier_pin, cashier_id: cashier.id }
    payload = payload_common.merge({ curgas_id: curgas_id, quantity: quantity, rush: rush })

    # call
    post CHECK_ORDER_URL, payload.to_json

    # verify response
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal resp["data"], body_mock[0]

    # verify cache
    cached_check_order = MemoryStore.get(CurgasService.order_cache_key(cods_identity))
    assert_equal cached_check_order["cods_identity"], cods_identity

    ## service call returned error code
    body_mock[0].merge!("error" => 2)
    stub_request(:get, url)
      .with(headers: { "Authorization" => "Bearer #{token_mock}" })
      .to_return(status: 200, body: body_mock.to_json, headers: {})

    # call
    post CHECK_ORDER_URL, payload.to_json

    # verify response
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal resp, { "check_order" => "Order has already been placed" }

    ## service call returned http error
    stub_request(:get, url)
      .with(headers: { "Authorization" => "Bearer #{token_mock}" })
      .to_return(status: 500, body: "500 server error", headers: {})

    # call
    post CHECK_ORDER_URL, payload.to_json

    # verify response
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal resp, { "http_error" => { "body" => "500 server error", "status" => 500 } }

    ##### new order

    ### no payload
    post NEW_ORDER_URL, {}.to_json
    assert last_response.unprocessable?
    assert_equal 11, JSON.parse(last_response.body).keys.size

    ### payload ok
    order_num = "123456"

    curgas_payload = {
      "company" => "01",
      "curgas_id" => curgas_id,
      "cods_identity" => cods_identity,
      "quantity_request" => quantity,
      "rush_delivery" => rush,
      "total_paid" => amount,
    }.to_json

    body_mock = [
      {
        "company" => "01",
        "curgas_id" => curgas_id,
        "cods_identity" => cods_identity,
        "quantity_request" => quantity,
        "rush_delivery" => rush,
        "total_paid" => amount,
        "order_num" => order_num,
        "error" => 0,
      },
    ]
    url = CurgasService::HOST_URL + CurgasService::NEW_ORDER_PATH
    stub_request(:post, url).with(body: curgas_payload, headers: { "Authorization" => "Bearer #{token_mock}" }).to_return(status: 200, body: body_mock.to_json, headers: {})

    payload_common.merge!(payment_method: "card", payment_method_type: "debit")
    digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + cods_identity.to_s)
    payload = payload_common.merge({ digest: digest, cods_identity: cods_identity })

    # call
    post NEW_ORDER_URL, payload.to_json

    # verify response
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal resp["data"], body_mock[0]

    # verify tx
    trx = Transaction.first
    assert_equal trx.type, "credit"
    assert_equal trx.amount, amount
    assert_equal trx.currency, operator.currency
    assert_equal trx.transaction_type, "service_mpos"
    assert_equal trx.reference_number, order_num
    assert_equal trx.status, "approved"
    assert_equal trx.customer_number, curgas_id
    assert_equal trx.operator_code, operator.code
    assert_equal trx.approval_code, cods_identity

    # asert relations
    assert account.transactions.first   # account has trx
    assert terminal.transactions.first  # terminal has trx
    assert cashier.transactions.first   # cashier has trx

    ### retry
    post "#{NEW_ORDER_URL}/retry", payload.to_json
    assert last_response.ok?
    assert_equal JSON.parse(last_response.body), resp
    assert_equal Transaction.first, Transaction.last
  end
end

require_relative "../integration_helper"
require "webmock"
include WebMock::API

class TestApiCloseServiceBatch < Test
  def setup
    super
    VCR.configure do |c|
      c.ignore_hosts "codsapi.curoil.com", "10.41.15.88", "tax.scalenext.io"
    end
    WebMock.enable!
  end

  def test_api_close_service_batch
    user = signup_user

    # card setup
    target_account = user.accounts.first
    card_pin = "1234"
    card = generate_card user, pin_block: card_pin
    card_number = card.pan

    account = generate_business_account user
    account.update credit_limit: 1000000
    time = Time.now
    terminal = generate_terminal account_id: account.id,
                                 opening_hours: time.hour - 1, opening_minutes: time.min - 2,
                                 closing_hours: time.hour + 1, closing_minutes: time.min + 2
    systan = 11111

    # create cashier
    login_user
    cashier, cashier_pin = create_cashier terminal

    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, terminal.services_batch_number)

    starting_batch_number = terminal.services_batch_number
    starting_batch_amount = terminal.batch_amount

    # no payload
    post "/api/close-services-batch", {}.to_json
    assert last_response.unprocessable?
    assert_equal 7, JSON.parse(last_response.body).keys.size

    # invalid access_token
    post "/api/close-services-batch", { access_token: "any", digest: "any",
                                        api_version: "1.0.0.", application_version: "1.0.0.",
                                        services_batch_number: starting_batch_number }.to_json
    assert last_response.unprocessable?
    assert_equal "unknown or disabled terminal", JSON.parse(last_response.body)["access_token"][0]

    # invalid digest
    post "/api/close-services-batch", { access_token: terminal.access_token, digest: "invalid",
                                        api_version: "1.0.0.", application_version: "1.0.0.",
                                        services_batch_number: starting_batch_number }.to_json
    assert last_response.unprocessable?
    assert_equal "is invalid", JSON.parse(last_response.body)["digest"][0]

    # close with non manager cashier
    post "/api/close-services-batch", { access_token: terminal.access_token, digest: digest,
                                        api_version: "1.0.0.", application_version: "1.0.0.",
                                        services_batch_number: starting_batch_number, cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.unprocessable?
    assert_equal "invalid manager pin", JSON.parse(last_response.body)["cashier_pin"][0]

    # close with inactive manager
    cashier.update(manager: true, active: false)
    post "/api/close-services-batch", { access_token: terminal.access_token, digest: digest,
                                        api_version: "1.0.0.", application_version: "1.0.0.",
                                        services_batch_number: starting_batch_number, cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.unprocessable?
    assert_equal "invalid manager pin", JSON.parse(last_response.body)["cashier_pin"][0]

    # try to close empty 1st batch with manager cashier
    cashier.update(active: true)
    post "/api/close-services-batch", { access_token: terminal.access_token, digest: digest,
                                        api_version: "1.0.0.", application_version: "1.0.0.",
                                        services_batch_number: starting_batch_number, cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert_equal "batch is empty", JSON.parse(last_response.body)["services_batch_number"][0]
    puts last_response.inspect

    # generate voucher and add stock
    generate_operator type: "voucher", code: "dc"
    product = Product.create name: "Digicel 25", price: 2500, currency: "USD", type: "voucher", operator_code: "dc"
    voucher = generate_voucher(name: "Digicel 25", price: 2500, operator_code: "dc")
    stock = VoucherStock.create(name: voucher.name, quantity: 10, product_id: product.id, operator_code: "dc")
    account.add_voucher_stock stock

    # do first sale
    sell_voucher terminal, "cash", "", cashier_pin, voucher.operator, voucher, cashier.id

    # close 1st with manager cashier
    cashier.update(manager: true) # promote cashier to manager
    post "/api/close-services-batch", { access_token: terminal.access_token, digest: digest,
                                        api_version: "1.0.0.", application_version: "1.0.0.",
                                        services_batch_number: starting_batch_number, cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)

    # test response fields
    assert_equal starting_batch_number + 1, resp["services_batch_number"]
    assert_equal "1.0.0.", resp["api_version"]
    assert_equal "1.0.0.", resp["application_version"]

    # check response digest
    assert_equal Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, resp["services_batch_number"]), resp["digest"]

    # test terminal attrs
    terminal.reload
    assert_equal starting_batch_number + 1, terminal.services_batch_number

    # test lodgment
    assert_equal 1, ServicesLodgment.count
    lodgment = ServicesLodgment.first

    ##############################################################################################################

    # do some sales for 2nd batch
    starting_batch_number = terminal.services_batch_number
    digest_for_2nd_batch = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, terminal.services_batch_number)

    # generate vouchers and add stock
    voucher_operator = generate_operator type: "voucher", code: "ch"

    # product 1
    product1 = Product.create name: "Chippie 10", price: 2500, currency: "USD", type: "voucher", operator_code: "ch"
    voucher1 = generate_voucher(name: "Chippie 10", price: 1000)
    stock = VoucherStock.create(name: voucher1.name, quantity: 10, product_id: product1.id, operator_code: "ch")
    account.add_voucher_stock stock

    # product 3
    product2 = Product.create name: "Chippie 25", price: 2500, currency: "USD", type: "voucher", operator_code: "ch"
    voucher2 = generate_voucher(name: "Chippie 25", price: 2500)
    stock = VoucherStock.create(name: voucher2.name, quantity: 20, product_id: product2.id, operator_code: "ch")
    account.add_voucher_stock stock

    # product 3
    product3 = Product.create name: "Chippie 50", price: 5000, currency: "USD", type: "voucher", operator_code: "ch"
    voucher3 = generate_voucher(name: "Chippie 50", price: 5000)
    stock = VoucherStock.create(name: voucher3.name, quantity: 30, product_id: product3.id, operator_code: "ch")
    account.add_voucher_stock stock

    ### sell 3 vouchers
    sell_voucher terminal, "cash", "", cashier_pin, voucher1.operator, voucher1, cashier.id
    sell_voucher terminal, "card", "debit", cashier_pin, voucher2.operator, voucher2, cashier.id
    sell_voucher terminal, "check", "sft", cashier_pin, voucher3.operator, voucher3, cashier.id

    ### pay 3 bils
    bill_operator = generate_operator name: "Aquaelectra", code: "ae", type: "bill", currency: "USD"
    customer = generate_customer operator_code: "ae"
    bill_payment_amount = 10000
    pay_bill terminal, "cash", "", bill_payment_amount * 1, cashier_pin, bill_operator, customer, systan + 1, cashier.id
    pay_bill terminal, "card", "debit", bill_payment_amount * 2, cashier_pin, bill_operator, customer, systan + 2, cashier.id
    pay_bill terminal, "check", "sft", bill_payment_amount * 3, cashier_pin, bill_operator, customer, systan + 3, cashier.id

    ### sell one prepaid
    prepaid_operator = generate_operator name: "Pagatinu", type: "prepaid", code: "pa", currency: "USD"
    prepaid_systan = 121212; prepaid_amount = 12345; prepaid_customer_number = "04229889888"
    prepaid_digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, prepaid_operator.code, prepaid_customer_number, prepaid_amount, prepaid_operator.currency, prepaid_systan)
    post "/api/sell-prepaid", { operator_code: prepaid_operator.code, customer_number: prepaid_customer_number, amount: prepaid_amount,
                                currency: prepaid_operator.currency, access_token: terminal.access_token, digest: prepaid_digest,
                                systan: prepaid_systan, api_version: "1.0.0.", application_version: "1.0.0.",
                                client_datetime: Time.now, payment_method: "card", payment_method_type: "debit",
                                cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.ok?

    ### pay one extra for reversal
    reversal_amount = 20000
    pay_bill terminal, "check", "sft", reversal_amount, cashier_pin, bill_operator, customer, systan + 4, cashier.id
    rev = Transaction.last
    reversal_digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, rev.id.to_s, systan + 4, reversal_amount)

    # reverse it now
    post "/api/reverse-bill-payment", { access_token: terminal.access_token, digest: reversal_digest, amount: reversal_amount, systan: systan + 4,
                                        api_version: "1.0.0.", application_version: "1.0.0.", client_datetime: Time.now,
                                        original_id: rev.id, cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.ok?

    ### topup
    topup_amount = 1000
    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, card_number, topup_amount, account.currency, systan)
    post "/api/top-up", { amount: topup_amount, currency: account.currency, access_token: terminal.access_token, digest: digest, card_pin: card_pin,
                          systan: systan, api_version: "1.0.0.", application_version: "1.0.0.", card_number: card_number, payment_method: "card",
                          payment_method_type: "debit", client_datetime: Time.now, cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.ok?

    ### wallet sales
    sale_amount = 500
    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, card_number, sale_amount, account.currency, systan)
    post "/api/sale-wallet", { amount: sale_amount, currency: account.currency, access_token: terminal.access_token, digest: digest,
                               systan: systan, api_version: "1.0.0.", application_version: "1.0.0.", card_number: card_number, card_pin: card_pin,
                               client_datetime: Time.now, cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.ok?

    ### curgas sale
    curgas_operator = generate_operator name: "Curgas", type: "api", code: "cg"
    # service data
    cods_identity = "456"
    curgas_id = "123"
    quantity = 10
    rush = 1
    curgas_amount = 1000

    # purge cache
    MemoryStore.delete(CurgasService::TOKEN_CACHE_KEY)
    MemoryStore.delete(CurgasService.order_cache_key(cods_identity))

    # login to service
    token_mock = "token"
    url = CurgasService::HOST_URL + CurgasService::LOGIN_PATH
    payload = { "username": CurgasService::USERNAME, "password": CurgasService::PASSWORD }.to_json
    stub_request(:post, url).with(body: payload).to_return(status: 200, body: token_mock, headers: {})
    CurgasService.login()

    payload_common = { operator_code: curgas_operator.code, access_token: terminal.access_token,
                       systan: systan, api_version: "1.0.0.", application_version: "1.0.0.",
                       client_datetime: Time.now, cashier_pin: cashier_pin, cashier_id: cashier.id }

    ## check order
    body_mock = [
      {
        "curgas_id" => curgas_id,
        "quantity_request" => quantity,
        "rush_delivery" => rush,
        "can_order" => "Y",
        "total_order" => curgas_amount,
        "cods_identity" => cods_identity,
        "error" => 0,
      },
    ]
    url = CurgasService::HOST_URL + CurgasService.check_order_path(curgas_id, quantity, rush)
    stub_request(:get, url).with(headers: { "Authorization" => "Bearer #{token_mock}" }).to_return(status: 200, body: body_mock.to_json, headers: {})

    digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + curgas_id.to_s + quantity.to_s + rush.to_s)
    payload = payload_common.merge({ curgas_id: curgas_id, quantity: quantity, rush: rush, digest: digest })

    # call
    post "/api/services/curgas/check-order", payload.to_json
    # verify response
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal resp["data"], body_mock[0]

    ## new order
    order_num = "123456"
    curgas_payload = {
      "company" => "01",
      "curgas_id" => curgas_id,
      "cods_identity" => cods_identity,
      "quantity_request" => quantity,
      "rush_delivery" => rush,
      "total_paid" => curgas_amount,
    }.to_json

    body_mock = [
      {
        "company" => "01",
        "curgas_id" => curgas_id,
        "cods_identity" => cods_identity,
        "quantity_request" => quantity,
        "rush_delivery" => rush,
        "total_paid" => curgas_amount,
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
    post "/api/services/curgas/new-order", payload.to_json
    # verify response
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal resp["data"], body_mock[0]

    ### pagatinu rest
    require_relative "../../fixtures/pagatinu_rest"

    datetime_format = "%Y%m%d%H%M%S"
    pagatinu_rest_url = "/api/services/pagatinu-rest/credit"

    # curgas_operator = generate_operator name: "Curgas", type: "api", code: "cg"
    pagatinu_rest_operator = generate_operator name: "Pagatinu REST", type: "api", code: "pg-rest"

    client_datetime = Time.now.to_s
    ms_no = "123456"
    systan = "123456789"
    pagatinu_rest_amount = 1000
    date_time = Time.now.strftime(datetime_format)

    stan_in_pagatinu_payload = terminal.id * 10000 + systan.to_i % 10000
    expected_pagatinu_payload = {
      "terminalID" => "0000000000002",
      "msNo" => ms_no,
      "stan" => stan_in_pagatinu_payload,
      "dateTime" => date_time,
      "purchaseValue" => pagatinu_rest_amount / 100.0,
      "operatorName" => "pagafasil",
      "password" => "pagafasil",
    }.to_json
    body_mock = VALID_BODY_MOCK # from imported fixture file

    url = PagatinuRestService::HOST_URL + PagatinuRestService::CREDIT_PATH
    stub_request(:post, url).with(body: expected_pagatinu_payload, headers: { "X-Api-Key" => PagatinuRestService::API_KEY }).to_return(status: 200, body: body_mock.to_json, headers: {})

    digest = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, ms_no, pagatinu_rest_amount, systan)

    payload_common = { operator_code: pagatinu_rest_operator.code, access_token: terminal.access_token, digest: digest,
                       api_version: "1.0.0.", application_version: "1.0.0.",
                       client_datetime: client_datetime, cashier_pin: cashier_pin, cashier_id: cashier.id }
    payload_common.merge!(payment_method: "card", payment_method_type: "debit")

    payload = payload_common.merge({ ms_no: ms_no, date_time: date_time, amount: pagatinu_rest_amount, systan: systan })

    # call
    post pagatinu_rest_url, payload.to_json
    assert last_response.ok?

    # resp = JSON.parse(last_response.body)
    # puts "resp ***"
    # puts resp
    # puts "resp ***"

    # puts "body_mock ***"
    # puts body_mock
    # puts "body_mock ***"

    # assert_equal resp["data"], {
    #   "customer_name" => "AGHA LIMITED",
    #   "datetime" => "2024-05-13T08:20:47.1317707-04:00",
    #   "terminal_id" => "0000000000002",
    #   "meter_number" => "04257670895",
    #   "receipt_number" => "10071872",
    #   "account_number" => "3101149376",
    #   "tariff" => "DOMESTIC ELECTRICITY",
    #   "energy_value" => "132.7",
    #   "energy2_value" => nil,
    #   "energy3_value" => nil,
    #   "energy_si_unit" => "kWh",
    #   "energy2_si_unit" => nil,
    #   "energy3_si_unit" => nil,
    #   "amount_paid_currency" => "XCG",
    #   "amount_paid_value" => "100",
    #   "token1" => "04257670895000001327",
    #   "token2" => nil,
    #   "token3" => nil,
    #   "customer_number" => "04257670895",
    #   "transaction_id" => "1230000001",
    # }

    ### tax sale
    tax_operator = generate_operator name: "Tax", type: "api", code: "tx"
    platform_id = "37281025-32da-48fb-bbac-abaeb6be0e88"
    request_time = "2025-03-09 15:53:46 -0400"
    payment_ref = "31201810010471"
    tax_amount = 100

    # from confirm_reference response
    reference_id = "252B6FE6-10FD-EF11-B879-549F350A9EA9"
    customer_id = "171476748"
    payment_period = "2018-13"
    tax_type = "AFS"

    # from payment response
    payment_id = "27C2B802-11FD-EF11-B879-549F350A9EA9"

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

    payment_mock = {
      "responseDescription" => "OK",
      "paymentId" => payment_id,
      "responseTime" => "2025-03-09 14:04:58.373",
      "responseValue" => "200",
      "platformId" => platform_id,
      "paymentAmount" => tax_amount.to_s,
      "paymentRef" => payment_ref,
    }

    # add confirm_reference to cache
    cache_key = TaxService.confirm_reference_cache_key(platform_id)
    # MemoryStore.delete(cache_key)
    MemoryStore.set(cache_key, confirm_reference_mock, TaxService::PAYMENT_TTL)

    url = TaxService::HOST_URL + TaxService::PAYMENT_PATH
    stub_request(:post, url)
      .with(headers: { "X-Api-Key" => TaxService::API_KEY, "Content-Type" => "application/json" })
      .to_return(status: 200, body: payment_mock.to_json, headers: {})

    payload_common.merge!(payment_method: "card", payment_method_type: "debit", systan: "123456789")
    digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + tax_amount.to_s + tax_operator.currency + platform_id.to_s)
    payload = payload_common.merge({ digest: digest, platform_id: platform_id, amount: tax_amount, currency: tax_operator.currency })

    # call
    post "/api/services/tax/payment", payload.to_json

    # verify response
    assert last_response.ok?

    ###################################################

    # check batch values
    total_batch_amount = voucher1.price + voucher2.price + voucher3.price + 6 * bill_payment_amount \
      + topup_amount + sale_amount + prepaid_amount + curgas_amount + pagatinu_rest_amount + tax_amount

    terminal.reload
    assert_equal total_batch_amount, terminal.batch_amount

    # close batch 2
    post "/api/close-services-batch", { access_token: terminal.access_token, digest: digest_for_2nd_batch,
                                        api_version: "1.0.0.", application_version: "1.0.0.",
                                        services_batch_number: starting_batch_number, cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.ok?
    pp JSON.parse(last_response.body)

    # check batch values
    terminal.reload
    assert_equal starting_batch_number + 1, terminal.services_batch_number

    # test lodgment attrs
    lodgment = ServicesLodgment.last
    assert_equal starting_batch_number, lodgment.batch_number
    assert_equal total_batch_amount, lodgment.batch_amount
    assert_equal terminal.default_currency, lodgment.currency

    ########################## test response fields
    resp = JSON.parse(last_response.body)
    assert_equal starting_batch_number + 1, resp["services_batch_number"]
    assert resp["starting_time"]
    assert resp["closing_time"]
    assert_equal cashier.full_name, resp["cashier"]

    ########################## reversals
    assert_equal "bill_mpos", resp["reversals"][0]["transaction_type"]
    assert_equal 1, resp["reversals"][0]["count"]
    assert_equal reversal_amount, resp["reversals"][0]["total"]

    #################### totals
    ### array of totals per trx type
    assert_equal "bill_mpos", resp["totals"][0]["transaction_type"]
    assert_equal 3, resp["totals"][0]["count"]
    assert_equal bill_payment_amount * 1 * 2 * 3, resp["totals"][0]["total"]

    assert_equal "prepaid_mpos", resp["totals"][1]["transaction_type"]
    assert_equal 1, resp["totals"][1]["count"]
    assert_equal prepaid_amount, resp["totals"][1]["total"]

    assert_equal "sale_wallet_mpos", resp["totals"][2]["transaction_type"]
    assert_equal 1, resp["totals"][2]["count"]
    assert_equal sale_amount, resp["totals"][2]["total"]

    # service_mpos (curgas + pagatinu_rest + tax)
    assert_equal "service_mpos", resp["totals"][3]["transaction_type"]
    assert_equal 3, resp["totals"][3]["count"]
    assert_equal curgas_amount + pagatinu_rest_amount + tax_amount, resp["totals"][3]["total"]

    assert_equal "top_up_mpos", resp["totals"][4]["transaction_type"]
    assert_equal 1, resp["totals"][4]["count"]
    assert_equal topup_amount, resp["totals"][4]["total"]

    assert_equal "voucher_mpos", resp["totals"][5]["transaction_type"]
    assert_equal 3, resp["totals"][5]["count"]
    assert_equal voucher1.price + voucher2.price + voucher3.price, resp["totals"][5]["total"]

    # net total
    net_total = voucher1.price + voucher2.price + voucher3.price + 1 * 2 * 3 * bill_payment_amount \
      - topup_amount - sale_amount + prepaid_amount + curgas_amount + pagatinu_rest_amount + tax_amount
    assert_equal net_total, resp["net_total"]["total"]
    assert_equal 12, resp["net_total"]["count"]

    ########################## service totals
    # per_payment_method
    assert_equal "card", resp["services"]["per_payment_method"][0]["payment_method"]
    assert_equal curgas_amount + pagatinu_rest_amount + tax_amount, resp["services"]["per_payment_method"][0]["total"]
    assert_equal 3, resp["services"]["per_payment_method"][0]["count"]

    # per cashier
    assert_equal "John Cashier", resp["services"]["per_cashier"][0]["full_name"]
    assert_equal curgas_amount + pagatinu_rest_amount + tax_amount, resp["services"]["per_cashier"][0]["total"]
    assert_equal 3, resp["services"]["per_cashier"][0]["count"]

    # per operator - curgas
    assert_equal "Curgas", resp["services"]["per_operator"][0]["name"]
    assert_equal curgas_amount, resp["services"]["per_operator"][0]["total"]
    assert_equal 1, resp["services"]["per_operator"][0]["count"]

    # per operator - pagatinu_rest
    assert_equal "Pagatinu REST", resp["services"]["per_operator"][1]["name"]
    assert_equal pagatinu_rest_amount, resp["services"]["per_operator"][1]["total"]
    assert_equal 1, resp["services"]["per_operator"][1]["count"]

    # per operator - tax
    assert_equal "Tax", resp["services"]["per_operator"][2]["name"]
    assert_equal tax_amount, resp["services"]["per_operator"][2]["total"]
    assert_equal 1, resp["services"]["per_operator"][2]["count"]

    ########################## bill totals
    # per_payment_method
    # one for card
    assert_equal "card", resp["bills"]["per_payment_method"][0]["payment_method"]
    assert_equal bill_payment_amount * 2, resp["bills"]["per_payment_method"][0]["total"]
    assert_equal 1, resp["bills"]["per_payment_method"][0]["count"]

    # one for cash
    assert_equal "cash", resp["bills"]["per_payment_method"][1]["payment_method"]
    assert_equal bill_payment_amount * 1, resp["bills"]["per_payment_method"][1]["total"]
    assert_equal 1, resp["bills"]["per_payment_method"][1]["count"]

    # two for check, one is reversal
    assert_equal "check", resp["bills"]["per_payment_method"][2]["payment_method"]
    assert_equal bill_payment_amount * 3 + reversal_amount, resp["bills"]["per_payment_method"][2]["total"] # reversal is in total sales
    assert_equal 2, resp["bills"]["per_payment_method"][2]["count"]

    # per cashier
    assert_equal "John Cashier", resp["bills"]["per_cashier"][0]["full_name"]
    assert_equal bill_payment_amount * 1 * 2 * 3, resp["bills"]["per_cashier"][0]["total"]
    assert_equal 3, resp["bills"]["per_cashier"][0]["count"]

    # per operator
    assert_equal "Aquaelectra", resp["bills"]["per_operator"][0]["name"]
    assert_equal bill_payment_amount * 1 * 2 * 3, resp["bills"]["per_operator"][0]["total"]
    assert_equal 3, resp["bills"]["per_operator"][0]["count"]

    ########################## voucher totals
    # per per_payment_method
    assert_equal "card", resp["vouchers"]["per_payment_method"][0]["payment_method"]
    assert_equal voucher2.price, resp["vouchers"]["per_payment_method"][0]["total"]
    assert_equal 1, resp["vouchers"]["per_payment_method"][0]["count"]

    assert_equal "cash", resp["vouchers"]["per_payment_method"][1]["payment_method"]
    assert_equal voucher1.price, resp["vouchers"]["per_payment_method"][1]["total"]
    assert_equal 1, resp["vouchers"]["per_payment_method"][1]["count"]

    assert_equal "check", resp["vouchers"]["per_payment_method"][2]["payment_method"]
    assert_equal voucher3.price, resp["vouchers"]["per_payment_method"][2]["total"]
    assert_equal 1, resp["vouchers"]["per_payment_method"][2]["count"]

    # per cashier
    assert_equal "John Cashier", resp["vouchers"]["per_cashier"][0]["full_name"]
    assert_equal voucher1.price + voucher2.price + voucher3.price, resp["vouchers"]["per_cashier"][0]["total"]
    assert_equal 3, resp["vouchers"]["per_cashier"][0]["count"]

    # per operator
    assert_equal "Chippie", resp["vouchers"]["per_operator"][0]["name"]
    assert_equal voucher1.price + voucher2.price + voucher3.price, resp["vouchers"]["per_operator"][0]["total"]
    assert_equal 3, resp["vouchers"]["per_operator"][0]["count"]

    ####################### test relations
    assert_equal 2, ServicesLodgment.count
    assert_equal 2, terminal.services_lodgments.count
    assert_equal 2, account.services_lodgments.count
    assert_equal 2, cashier.services_lodgments.count

    # close for inactive terminal
    terminal.update(active: false)
    post "/api/close-services-batch", { access_token: terminal.access_token, digest: digest,
                                        api_version: "1.0.0.", application_version: "1.0.0.",
                                        services_batch_number: starting_batch_number, cashier_pin: cashier_pin, cashier_id: cashier.id }.to_json
    assert last_response.unprocessable?
    assert_equal "unknown or disabled terminal", JSON.parse(last_response.body)["access_token"][0]
  end
end

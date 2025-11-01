require_relative "../integration_helper"

class TestApiConfigureTerminal < Test
  def test_api_configure_terminal
    access_token = "configure_api_access_token"
    terminal_key = "configure_api_terminal_key"

    # create terminal on switch
    # InfoSwitch::TerminalApi.new.create_or_update(
    #   location_indicator: 'merchant',
    #   load_balancer: 'Vidanova::WebpayPos',
    #   status: 'active',
    #   authenticity_token: access_token,
    #   secret: terminal_key,
    #   name: 'WebPay Integration POS, test run',
    #   regenerate_tmk: true,
    #   mid: 'Terminal'
    # )

    user = signup_user
    account = user.accounts.first
    terminal = generate_terminal account_id: account.id, accepted_cards: ["visa"],
                                 infoswitch_enabled: true, access_token: access_token, terminal_key: terminal_key

    digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token)

    # activate one service
    account.update(top_up: true)

    # create cashiers
    login_user
    cashier1, cashier_pin = create_cashier terminal, { full_name: "John Cashier", manager: true }
    cashier2, cashier_pin = create_cashier terminal, { full_name: "Joe Cashier", manager: false }
    cashier3, cashier_pin = create_cashier terminal, { full_name: "Jim Cashier", manager: true, active: false }

    # generate bill operators
    operator = generate_operator name: "Aquaelectra", code: "ae", type: "bill"
    operator = generate_operator name: "Selikor", code: "se", type: "bill", active: false

    # generate voucher operators
    operator1 = generate_operator code: "ch", name: "Chippie"
    operator2 = generate_operator code: "dc", name: "Digicell"

    # generate products tempaltes for stock
    product1 = Product.create name: "Chippie 100", price: 10000, currency: "USD", type: "voucher", operator_code: "ch"
    product2 = Product.create name: "Digicell 100", price: 10000, currency: "USD", type: "voucher", operator_code: "dc"
    product3 = Product.create name: "Digicell 50", price: 5000, currency: "USD", type: "voucher", operator_code: "dc"
    product4 = Product.create name: "Digicell 75", price: 7500, currency: "USD", type: "voucher", operator_code: "dc"

    stock1 = VoucherStock.create(name: product1.name, operator_code: product1.operator_code, product_id: product1.id,
                                 quantity: 100, account_id: terminal.account_id)
    stock2 = VoucherStock.create(name: product2.name, operator_code: product2.operator_code, product_id: product2.id,
                                 quantity: 100, account_id: terminal.account_id)
    stock3 = VoucherStock.create(name: product3.name, operator_code: product3.operator_code, product_id: product3.id,
                                 quantity: 50, account_id: terminal.account_id)
    stock4 = VoucherStock.create(name: product4.name, operator_code: product4.operator_code, product_id: product4.id,
                                 quantity: 75, account_id: terminal.account_id)

    # no payload
    post "/api/configure-terminal", {}.to_json
    assert last_response.unprocessable?
    assert_equal 4, JSON.parse(last_response.body).keys.size

    # invalid access_token
    post "/api/configure-terminal", { access_token: "any", digest: "any",
                                      api_version: "1.0.0.", application_version: "1.0.0." }.to_json
    assert last_response.unprocessable?
    assert_equal "unknown or disabled terminal", JSON.parse(last_response.body)["access_token"][0]

    # invalid digest
    post "/api/configure-terminal", { access_token: terminal.access_token, digest: "invalid",
                                      api_version: "1.0.0.", application_version: "1.0.0." }.to_json
    assert last_response.unprocessable?
    assert_equal "is invalid", JSON.parse(last_response.body)["digest"][0]

    # configure now
    post "/api/configure-terminal", { access_token: terminal.access_token, digest: digest,
                                      api_version: "1.0.0.", application_version: "1.0.0." }.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)

    pp resp

    # test response fields
    assert_equal terminal.id, resp["terminal_id"]
    assert_equal ["USD", "EUR"], resp["accepted_currencies"]
    assert_equal ({ "USD" => 840, "EUR" => 978 }), resp["currency_codes"]
    assert resp["wallet_to_card_types"]
    assert_equal ["visa"], resp["accepted_cards"]
    assert_equal "1.0.0.", resp["api_version"]
    assert_equal "1.0.0.", resp["application_version"]
    assert_equal ([]), resp["payment_methods"][0]["types"]
    assert_equal MPOS_CARD_PAYMENT_METHOD_TYPES[0][:name], resp["payment_methods"][1]["types"][0]["name"]
    assert_equal MPOS_CHECK_PAYMENT_METHOD_TYPES[0][:name], resp["payment_methods"][2]["types"][0]["name"]
    assert_equal [{ "id" => cashier2.id, "full_name" => cashier2.full_name, "manager" => false },
                  { "id" => cashier1.id, "full_name" => cashier1.full_name, "manager" => true }], resp["cashiers"]

    # services flags
    assert_equal resp["services"], { "sell_vouchers" => false,
                                     "sell_prepaids" => false,
                                     "bill_payments" => false,
                                     "top_up" => true,
                                     "card_authorization" => false,
                                     "sale_wallet" => false,
                                     "service_curgas" => true,
                                     "service_tax" => true }

    # check for session_keys
    terminal.reload
    # assert_equal ["version", "pin_key", "pin_key_kcv", "data_key", "data_key_kcv", "mac_key", "mac_key_kcv", "terminal_parameters", "server_time"], resp['infoswitch'].keys,
    #   'infoswitch response fields look strange'

    # check response digest
    assert_equal Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + resp["config_version"].to_s), resp["digest"]

    # test operators/voucher structure
    # "operators"=>[{"name"=>"Aquaelectra", "code"=>"ae", "currency"=>"USD", "type"=> "bill"},
    #               {"name"=>"Chippie", "code"=>"ch", "currency"=>"USD", "type"=> "voucher"},
    #               {"name"=>"Digicell", "code"=>"dc", "currency"=>"USD", "type"=> "voucher"}]
    #
    # "vouchers"=>[{"name"=>"Chippie 100", "operator_code"=>"ch", "quantity"=>2, "currency"=>"USD", "price"=> 100},
    #              {"name"=>"Digicell 100", "operator_code"=>"dc", "quantity"=>1, "currency"=>"USD", "price"=> 100}]

    # 3 operators
    # first
    assert_equal "Aquaelectra", resp["operators"][0]["name"]
    assert_equal "ae", resp["operators"][0]["code"]
    assert_equal "USD", resp["operators"][0]["currency"]
    assert_equal "bill", resp["operators"][0]["type"]
    assert_equal operator.info, resp["operators"][0]["info"]

    # other two
    assert_equal "Chippie", resp["operators"][1]["name"]
    assert_equal "voucher", resp["operators"][1]["type"]
    assert_equal "Digicell", resp["operators"][2]["name"]

    # vouchers - ordered by price and name
    # first
    assert_equal "Digicell 50", resp["vouchers"][0]["name"]
    assert_equal 50, resp["vouchers"][0]["quantity"]

    # second
    assert_equal "Digicell 75", resp["vouchers"][1]["name"]
    assert_equal 75, resp["vouchers"][1]["quantity"]

    # third
    assert_equal "Chippie 100", resp["vouchers"][2]["name"]
    assert_equal 100, resp["vouchers"][2]["quantity"]

    # fourth
    assert_equal "Digicell 100", resp["vouchers"][3]["name"]
    assert_equal 100, resp["vouchers"][3]["quantity"]

    # broken test
    # downloads_folder
    # file_name = 'mainapp_1.2.3'
    # assert_equal file_name, resp['downloads']['mainapp']['name']
    # assert_equal '1.2.3',   resp['downloads']['mainapp']['version']
    # assert_equal Digest::SHA512.file("#{DownloadConfig::DOWNLOADS_FOLDER}/#{file_name}").hexdigest, resp['downloads']['mainapp']['checksum']

    # configure for inactive terminal
    terminal.update(active: false)
    post "/api/configure-terminal", { access_token: terminal.access_token, digest: digest,
                                      api_version: "1.0.0.", application_version: "1.0.0." }.to_json
    assert last_response.unprocessable?
    assert_equal "unknown or disabled terminal", JSON.parse(last_response.body)["access_token"][0]
  end
end

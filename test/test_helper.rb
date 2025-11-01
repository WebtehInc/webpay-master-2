unless ENV["WP_ENV"] == "test"
  puts
  puts "*" * 30
  puts "* WP_ENV must be set to test *"
  puts "*" * 30
  exit
end

# curgas env
ENV["CG_HOST_URL"] = "https://codsapi.curoil.com"
ENV["CG_USERNAME"] = "pagafasil"
ENV["CG_PASSWORD"] = "pagafasil"

# pagatinuV2 env
ENV["PG_HOST_URL"] = "https://blue.ppe2.net"
ENV["PG_RECHARGE_PATH"] = "/srater2-web/resources/recharge"
ENV["PG_PAYMENT_PROVIDER"] = "Pagafasil"
ENV["PG_USERNAME"] = "pagafasil"
ENV["PG_PASSWORD"] = "pagafasil"

# pagatinu rest env
ENV["PG_REST_HOST_URL"] = "http://10.41.15.88"
ENV["PG_REST_TERMINAL_ID"] = "0000000000002"
ENV["PG_REST_OPERATOR_NAME"] = "pagafasil"
ENV["PG_REST_PASSWORD"] = "pagafasil"
ENV["PG_REST_API_KEY"] = "pagafasil"

# TAX
ENV["TAX_HOST_URL"] = "https://tax.scalenext.io"
ENV["TAX_API_KEY"] = "j8m64901rxvg1nk0asu3s2fbx4tjw8"

require_relative "helpers/luhnacy"

require "vcr"
require "awesome_print"

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :faraday
  config.ignore_localhost = true
end

require "minitest/autorun"

require_relative "helpers/stub_any_instance"

class Minitest::Test
  def setup
    # wipe data
    [:login_trails, :cards, :audits, :transactions, :reversals, :vouchers, :customers, :operators, :services_lodgments, :voucher_stocks,
     :cashiers, :devices, :terminals, :accounts_users, :limits, :users, :accounts, :cashiers, :products, :fees].each { |table| DB[table].delete }

    # cassette_name = self.class.to_s.underscore + "/" + name.gsub(/^test_[0-9]+_/, 'test_it_') # TODO: no ActiveSupport string helpers are available here
    VCR.turn_on!
    @__vcr_cassette_name = self.class.to_s.gsub("::", "/") + "/" + name.gsub(/^test_[0-9]+_/, "test_it_")
    VCR.insert_cassette(@__vcr_cassette_name)
  end

  def teardown
    VCR.eject_cassette if VCR.current_cassette
  end

  # :terminal_id, :account_id, :user_id, :parent_id, :type, :api_version, :application_version, :tid, :mid,
  # :systan, :entry_method, :amount, :currency, :number_of_installments, :transaction_type, :pan, :exp_date,
  # :ch_authentication, :pin_block, :ch_name, :emv_data, :track1, :track2, :track3, :approval_code, :reference_number,
  # :response_code, :response_message, :status
  def generate_transaction(attrs = {})
    Transaction.create({ amount: 12345, currency: "USD", status: "approved",
                         transaction_type: "authorization", type: "mPOS", balance: 12345 }.merge(attrs))
  end

  # :account_id, :access_token, :terminal_key, :merchant_name, :tid, :mid, :default_currency,
  # :accepted_currencies, :accepted_cards, :number_of_installments, :receipt_text, :active
  def generate_terminal(attrs = {})
    fixed_access_token = attrs.delete(:access_token)
    access_token = fixed_access_token || Utils.generate_random_token
    infoswitch_enabled = attrs.delete(:infoswitch_enabled)
    generate_session_keys = attrs.delete(:generate_session_keys)

    terminal = Terminal.create({ access_token: access_token, merchant_name: "Merchant", terminal_key: "abc123",
                                 accepted_currencies: ["USD", "EUR"], batch_limit: 500000, amount_limit: 50000, active: true,
                                 default_currency: "USD", tid: "000123", mid: "000123", accepted_cards: ["visa"] }.merge(attrs))

    if infoswitch_enabled
      raise "you need to set a fixed access token to use infoswitch_enabled option or you'll create a new terminal for every test run" unless fixed_access_token
      m = InfoSwitch::Mocks.new(authenticity_token: "WebpayIntegrationPOS-test")

      terminal_api = InfoSwitch::TerminalApi.new
      infoswitch_terminal = terminal_api.create_or_update_terminal(
        m.create_or_update_terminal.merge(
          name: "WebPay Integration POS, test environment",
          generate_tmk: true,
          transport_key: "tmk_test",
          load_balancer: "DummyBalancer",
          default_acquirer_logid: "xml-sim",
        ).merge(InfoSwitch.api_keys("Terminal", fixed_access_token))
      )
      assert_equal "updated", infoswitch_terminal["status"], "something funny happened with the infoswitch api call, response: #{infoswitch_terminal}"

      if generate_session_keys
        pos_api = InfoSwitch::PosApi.new
        pos_api.configure_terminal(m.configure_terminal)
      end
    end

    terminal
  end

  def generate_business_account(user)
    account_number = Account.generate_account_number
    # iban = Account.generate_iban(account_number)

    user.add_account({ title: "Simple business account", type: "business", currency: WebPay.opts[:default_curency],
                       # iban: iban,
                       account_number: account_number,
                       sell_vouchers: true, sell_prepaids: true, bill_payments: true, top_up: true, card_authorization: true, sale_wallet: true,
                       settings: ACCOUNT_SETTINGS })
  end

  def generate_bank_account(user, type, attrs = {})
    account_number = Account.generate_account_number
    user.add_account({ title: "Bank #{type} account", type: type, currency: WebPay.opts[:default_curency],
                       account_number: account_number }.merge(attrs))
  end

  # :name, :code, :type, :active
  def generate_operator(attrs = {})
    Operator.create({ name: "Chippie", code: "ch", type: "voucher", currency: "USD", info: 'Info 1\nInfo2', active: true }.merge(attrs))
  end

  # :operator_code, :terminal_id, :uid, :name, :value, :batch_number, :status
  def generate_voucher(attrs = {})
    v = Voucher.new({ operator_code: "ch", uid: rand(1000000000), name: "Chippie 100", batch_number: 1,
                      status: "available", price: 10000, currency: "USD" }.merge(attrs))

    # link voucher to product
    product = Product.where(name: v.name).first
    product = Product.create({ name: v.name, price: v.price, currency: v.currency,
                               type: "voucher", operator_code: v.operator_code }) unless product
    v.product_id = product.id

    encrypted_data = v.encrypted_sensitive_data(value: attrs[:value] || Utils.generate_random_token)
    v.value = encrypted_data[:value]
    v.default_key_label = encrypted_data[:key_label]

    v.save_changes
  end

  # :operator_code, :number, :balance, :active
  def generate_customer(attrs = {})
    Customer.create({ operator_code: "ch", number: 44444, balance: -100000, currency: "USD" }.merge(attrs))
  end

  # template for voucher stock
  def generate_product(attrs = {})
    Product.create({ name: "Chippie 100", price: 10000, currency: "USD", type: "voucher", operator_code: "ch" }.merge(attrs))
  end

  def generate_card(user, attrs = {})
    bin = "4400"
    pan = Luhnacy.generate(16, :prefix => bin)
    fixed_access_token = attrs.delete(:access_token)
    # access_token = fixed_access_token || Utils.generate_random_token
    infoswitch_enabled = attrs.delete(:infoswitch_enabled)

    card = Card.create({ user_id: user.id, first_name: user.first_name, last_name: user.last_name, active: true, pin_block: "1234",
                         bin: bin, pan: pan, masked_pan: Card.mask_pan(pan), hashed_pan: Digest::SHA512.hexdigest(pan), exp_month: Time.now.month, exp_year: Time.now.year + 1,
                         type: "tag", serial_number: rand(100000),
                         cmk: "tmk_test:HMMZL4ElH38VZQLD7S+1Zg==", cmk_kcv: "1ec1f5" }.merge(attrs))

    if infoswitch_enabled
      raise "you need to set a fixed access token to use infoswitch_enabled option or you'll create a new terminal for every test run" unless fixed_access_token
      m = InfoSwitch::Mocks.new(authenticity_token: "WebpayIntegrationPOS-test")

      mifare_api = InfoSwitch::MifareApi.new
      infoswitch_card = mifare_api.generate_master_key(
        m.mifare_generate_master_key.merge(InfoSwitch.api_keys("Terminal", fixed_access_token))
      )
      card.update(cmk: infoswitch_card["cmk_host"], cmk_kcv: infoswitch_card["cmk_kcv"])
    end

    card
  end
end

require_relative 'demo_helper'

class UpdateOldData < Demo

  def test_update_old_data
    puts 'update old users'
    User.dataset.update(active: true)

    puts
    puts 'update old accounts'
    # :id, :title, :iban, :account_number, :currency, :balance, :active, :created_at, :updated_at,
    # :exposure_amount, :merchant_name, :merchant_description, :merchant_address, :merchant_phone,
    # :merchant_email, :merchant_fax, :exposure_limit, :min_amount, :max_amount, :credit_limit,
    # :merchant_contact, :type, :sell_vouchers, :sell_prepaids, :bill_payments, :top_up, :card_authorization
    Account.order(:id).all.each do |acc|
      merchant_name = Faker::Company.name
      puts "updating account ##{acc.id}"
      acc.title = "#{merchant_name} business account"
      acc.currency = CURRENCY
      acc.active = true
      acc.balance = rand(10000000) + 10000
      acc.exposure_amount = rand(100000) + 10000
      acc.credit_limit = rand(1000000) + 10000
      acc.merchant_name = merchant_name
      acc.merchant_description = Faker::Company.catch_phrase
      acc.merchant_address = Faker::Address.street_address
      acc.merchant_phone = rand(9999999999)
      acc.merchant_email = Faker::Internet.safe_email
      acc.merchant_fax = rand(9999999999)
      acc.merchant_contact = Faker::Name.name
      acc.type = 'business'
      acc.sell_vouchers = true
      acc.sell_prepaids = true
      acc.bill_payments = true
      acc.top_up = true
      acc.card_authorization = true
      acc.save
    end

    puts
    puts 'update old terminals'
    # :id, :account_id, :access_token, :terminal_key, :merchant_name, :tid, :mid, :default_currency, :accepted_currencies,
    # :accepted_cards, :number_of_installments, :receipt_text, :active, :created_at, :updated_at,
    # :merchant_address, :merchant_phone, :merchant_email, :batch_limit, :amount_limit, :batch_amount, :config_version,
    # :session_keys, :bill_cash_amount, :bill_card_amount, :bill_check_amount, :voucher_cash_amount, :voucher_card_amount,
    # :voucher_check_amount, :services_batch_number, :services_batch_start_date, :exposure_amount, :batch_trx_counter, :trx_counter
    Terminal.order(:id).all.each do |t|
      puts "updating terminal ##{t.id}"
      t.default_currency = CURRENCY
      t.accepted_currencies = [CURRENCY]
      t.active = true
      t.merchant_name = t.account.merchant_name
      t.merchant_address = Faker::Address.street_address
      t.merchant_phone = rand(9999999999)
      t.save
    end

    puts
    puts 'generating voucher stock'
    # :id, :account_id, :name, :quantity, :sales_count, :last_purchase_quantity, :last_purchase_at, :active,
    # :created_at, :updated_at, :product_id, :operator_code, :notify_quantity
    Account.all.each do |acc|
      puts "generating voucher stocks for account ##{acc.id}"
      Product.all.each do |p|
        puts "stock for #{p.name}"
        acc.add_voucher_stock name: p.name, operator_code: p.operator_code, product_id: p.id,
                              active: true, notify_quantity: 10, account_id: acc.id, quantity: 100
      end
    end

    puts
    puts 'generating cashiers'
    Terminal.all.each do |t|
      puts "generating cashier for terminal ##{t.id}"

      random_pin = Utils.random_pin(4)
      Cashier.create  terminal_id: t.id, full_name: Faker::Name.name,
                      hashed_pin: Digest::SHA512.hexdigest(random_pin), manager: true
    end

    puts '---------------------------'
    puts "Users: #{User.count}"
    puts "Accounts: #{Account.count}"
    puts "Terminals: #{Terminal.count}"
  end
end
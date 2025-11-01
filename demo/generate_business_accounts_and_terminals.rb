require_relative 'demo_helper'

class GenerateBusinessAccounts < Demo

  def test_generate_business_accounts

    puts 'Generating business accounts and terminals:'
    puts '---------------------------'
    User.all.each do |u|
      puts "Client ##{u.id}"
      merchant_name = Faker::Company.name
      u.add_account title: "#{merchant_name} business account",
                    currency: CURRENCY,
                    account_number: Account.generate_account_number,
                    active: true,
                    balance: rand(10000000) + 10000,
                    exposure_amount: rand(100000) + 10000,
                    credit_limit: rand(1000000) + 10000,
                    merchant_name: merchant_name,
                    merchant_description: Faker::Company.catch_phrase,
                    merchant_address: Faker::Address.street_address,
                    merchant_phone: rand(9999999999),
                    merchant_email: Faker::Internet.safe_email,
                    merchant_fax: rand(9999999999),
                    merchant_contact: Faker::Name.name,
                    type: 'business',
                    sell_vouchers: true,
                    sell_prepaids: true,
                    bill_payments: true,
                    top_up: true,
                    card_authorization: true,
                    settings: ACCOUNT_SETTINGS
    end

    puts
    puts 'Generating terminals'
    puts '---------------------------'
    Account.where(type: 'business').all.each do |acc|
      puts "=> generating terminal for account ##{acc.id}"
      acc.add_terminal  default_currency: CURRENCY,
                        accepted_currencies: [CURRENCY],
                        accepted_cards: ACCEPTED_CARDS.keys.stringify,
                        active: true,
                        merchant_name: acc.merchant_name,
                        merchant_address: Faker::Address.street_address,
                        merchant_phone: rand(9999999999),
                        opening_hours: 0,
                        opening_minutes: 0,
                        closing_hours: 23,
                        closing_minutes: 59,
                        access_token: Utils.generate_random_token,
                        terminal_key: 'abc123'
    end

    puts
    puts 'Generating cashier:'
    puts '---------------------------'
    Terminal.all.each do |t|
      puts "=> generating cashier for terminal ##{t.id}"

      random_pin = Utils.random_pin(4)
      Cashier.create  terminal_id: t.id, full_name: Faker::Name.name,
                      hashed_pin: Digest::SHA512.hexdigest(random_pin), manager: true
    end

    puts
    puts 'Generating voucher stocks:'
    puts '---------------------------'
    # :id, :account_id, :name, :quantity, :sales_count, :last_purchase_quantity, :last_purchase_at, :active,
    # :created_at, :updated_at, :product_id, :operator_code, :notify_quantity
    Account.where(type: 'business').all.each do |acc|
      puts "=> generating voucher stocks for account ##{acc.id}"
      Product.all.each do |p|
        puts "stock for #{p.name}"
        acc.add_voucher_stock name: p.name, operator_code: p.operator_code, product_id: p.id,
                              active: true, notify_quantity: 10, account_id: acc.id, quantity: 100
      end
    end

    puts
    puts 'Summary:'
    puts '---------------------------'
    puts "Business accounts: #{Account.where(type: 'business').count}"
    puts "Terminals: #{Terminal.count}"
    puts "Voucher stocks: #{VoucherStock.count}"

  end

end

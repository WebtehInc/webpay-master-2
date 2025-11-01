require_relative 'demo_helper'

class GenerateMposTransactions < Demo

  def test_generate_mpos_transactions

    puts 'Generating mPos transactions:'
    puts '-----------------------------'

    # terminals = [Terminal[5127]]
    terminals = Terminal.all

    voucher_names = DB[:products].select(:name).all
    operators = DB[:operators].where(type: 'bill').select(:name, :code, :currency).all
    personal_accounts = Account.where(type: 'personal').all

    terminals.each do |t|

      # update pin
      cashier_pin = Utils.random_pin(4)
      if cashier = t.cashiers.last
        cashier.hashed_pin = Digest::SHA512.hexdigest(cashier_pin)
        cashier.save
      end

      ARGV[0].to_i.times do |n|

        target_account = personal_accounts.sample
        paying_amount = (rand(20000) + 2000)

        begin
          voucher_name = voucher_names.sample[:name]
          payment_method_and_type = MPOS_PAYMENT_METHODS_AND_TYPES.sample
          payment_method = payment_method_and_type[:payment_method]
          payment_method_type = payment_method_and_type[:types].sample[:payment_method_type] rescue ''

          puts; puts "*** wallet sale on terminal ##{t.id}"
          systan = rand(1000000).to_s
          card = target_account.users.first.cards.first
          digest = Utils.digest_SHA512(t.terminal_key, t.access_token, card.pan, paying_amount, CURRENCY, systan)
          post '/api/sale-wallet', {amount: paying_amount, currency: CURRENCY, access_token: t.access_token, digest: digest,
                                    systan: systan, api_version: '1.0.0.', application_version: '1.0.0.', card_number: card.pan, card_pin: PIN_BLOCK,
                                    client_datetime: Time.now, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json

          puts; puts "*** topup on terminal ##{t.id}"
          systan = rand(1000000).to_s
          digest = Utils.digest_SHA512(t.terminal_key, t.access_token, target_account.account_number, paying_amount, CURRENCY, systan)
          post '/api/top-up', { amount: paying_amount, currency: CURRENCY, access_token: t.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.', account_number: target_account.account_number,
                                client_datetime: Time.now, cashier_pin: cashier_pin, cashier_id: cashier.id,
                                payment_method: payment_method, payment_method_type: payment_method_type}.to_json

          next if [true, false].sample # reverse some
          trx = Transaction.last
          puts; puts "*** reversing topup for trx ##{trx.id}"
          digest = Utils.digest_SHA512(t.terminal_key, t.access_token, trx.id - 1, systan, paying_amount)
          post '/api/reverse-top-up', { access_token: t.access_token, digest: digest, amount: paying_amount, systan: systan,
                                        api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: Time.now,
                                        original_id: trx.id - 1, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json

          puts; puts "*** sell voucher on terminal ##{t.id}"
          systan = rand(1000000).to_s
          digest = Digest::SHA512.hexdigest(t.terminal_key + t.access_token + voucher_name + systan)
          post '/api/sell-voucher', { name: voucher_name, access_token: t.access_token, digest: digest,
                                      systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                      client_datetime: Time.now, payment_method: payment_method,
                                      payment_method_type: payment_method_type, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json

          puts; puts "*** pay bill on terminal ##{t.id}"
          systan = rand(1000000).to_s
          operator = operators.sample
          customer_number =  %w(11111 22222 33333 44444 55555).sample.to_s
          digest = Digest::SHA512.hexdigest(t.terminal_key + t.access_token + operator[:code] + customer_number +
                                            paying_amount.to_s + CURRENCY + systan)
          post '/api/bill-payment', { operator_code: operator[:code], customer_number: customer_number, amount: paying_amount,
                                      currency: CURRENCY, access_token: t.access_token, digest: digest,
                                      systan: systan, api_version: '1.0.0.', application_version: '1.0.0.',
                                      client_datetime: Time.now, payment_method: payment_method,
                                      payment_method_type: payment_method_type, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json

          next if [true, false].sample # reverse some
          trx = Transaction.last
          puts; puts "*** reversing bill payment for trx ##{trx.id}"
          digest = Digest::SHA512.hexdigest(t.terminal_key + t.access_token + trx.id.to_s + trx.systan + trx.amount.to_s)
          post '/api/reverse-bill-payment', { access_token: t.access_token, digest: digest, amount: trx.amount, systan: trx.systan,
                                              api_version: '1.0.0.', application_version: '1.0.0.', client_datetime: Time.now,
                                              original_id: trx.id, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json

        rescue Interrupt => e
          puts "\nTerminated manually."
          exit
        rescue Exception => e
          puts "failed for terminal ##{t.id}"
          puts "#{e.class} #{e.message}"
        end

      end
    end

    puts
    puts 'Summary:'
    puts '---------------------------'
    puts "Top up transactions: #{Transaction.where(transaction_type: 'top_up_mpos').count}"
    puts "Voucher transactions: #{Transaction.where(transaction_type: 'voucher_mpos').count}"
    puts "Bill transactions: #{Transaction.where(transaction_type: 'bill_mpos').count}"
  end
end

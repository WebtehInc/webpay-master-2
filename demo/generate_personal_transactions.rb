require_relative 'demo_helper'

class GeneratePersonalTransactions < Demo

  def test_generate_personal_transactions

    puts 'Generating personal transactions:'
    puts '---------------------------'

    # users = [User[217], User[216], User[215], User[214]]
    users = User.all

    voucher_names = DB[:products].select(:name).all
    operators = DB[:operators].where(type: 'bill').select(:name, :code, :currency).all

    users.each do |u|
      source_account = u.accounts_dataset.where(type: 'personal').all.sample
      target_account = users.sample.accounts_dataset.where(type: 'personal').all.sample

      login_user u
      authorize_with_otp u
      puts "=> buying voucher by user ##{u.id}"
      post '/buy-voucher', { name: voucher_names.sample[:name], account_id: source_account.id }.to_json rescue nil

      operator = operators.sample
      puts "=> paying bill by user ##{u.id} to #{operator[:name]}"
      post '/pay-bill', { operator_code: operator[:code], customer_number: %w(11111 22222 33333 44444 55555).sample,
                          amount: rand(10000) + 500, account_id: source_account.id }.to_json rescue nil

      puts "=> transfering from #{source_account.account_number} to #{target_account.account_number}" rescue nil
      post 'transfer', {source_account_id: source_account.id, target_account_id: target_account.account_number,
                       amount: rand(20000) + 500, currency: CURRENCY, note: 'This is a note'}.to_json rescue nil
    end

    puts
    puts 'Summary:'
    puts '---------------------------'
    puts "Voucher transactions: #{Transaction.where(transaction_type: 'voucher').count}"
    puts "Bill transactions: #{Transaction.where(transaction_type: 'bill').count}"
    puts "Transfer transactions: #{Transaction.where(transaction_type: 'transfer').count}"

  end

end

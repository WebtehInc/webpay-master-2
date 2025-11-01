require_relative 'demo_helper'

class GeneratePersonalAccounts < Demo

  def test_generate_personal_accounts

    puts 'Generating personal accounts:'
    puts '---------------------------'
    User.all.each do |u|
      puts "Client ##{u.id}"
      u.add_account title: "Simple personal account",
                    currency: CURRENCY,
                    account_number: Account.generate_account_number,
                    type: 'personal',
                    active: true,
                    balance: rand(10000000) + 10000
    end

    puts
    puts 'Summary:'
    puts '---------------------------'
    puts "Users: #{User.count}"
    puts "Personal accounts: #{Account.where(type: 'personal').count}"
  end

end
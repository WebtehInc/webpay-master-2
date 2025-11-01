require_relative 'demo_helper'

class GenerateCustomers < Demo

  def test_generate_customers

    puts 'Generating customers:'
    puts '---------------------------'
    # :id, :operator_code, :number, :balance, :active, :created_at, :updated_at, :currency
    Operator.where(type: 'bill').all do |o|
      puts "=> Generating customers for #{o.name}"
      begin # if it already exists
        %w(11111 22222 33333 44444 55555).each do |n|
          c = Customer.create operator_code: o.code, number: n,  balance: -(rand(500000)), currency: CURRENCY, active: true
          puts "Customer number: ##{c.number}: Balance: #{c.balance} #{c.currency}"
        end
      rescue
        puts 'Already generated'
      end
      puts
    end

    puts
    puts 'Summary:'
    puts '---------------------------'
    puts "Customers: #{Customer.count}"
  end

end


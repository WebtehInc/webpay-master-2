require_relative 'demo_helper'

class GenerateVouchers < Demo

  def test_generate_vouchers

    puts 'Generating vouchers:'
    puts '---------------------------'
    # :id, :operator_code, :terminal_id, :uid, :name, :value, :batch_number, :status, :created_at, :updated_at,
    # :price, :currency, :default_key_label,
    # :revealed_by, :revealed_at, :revealed, :product_id

    # :id, :name, :price, :currency, :type, :operator_code, :created_at, :updated_at,
    # :info, :quantity, :notify_quantity, :replenished_at
    Product.order(Sequel.desc(:name)).all.each do |p|
      puts "=> Generating vouchers for #{p.name}"
      ARGV[0].to_i.times do |n|
        n = n + 1
        puts "##{n}: #{p.name}"
        begin
          v = Voucher.new operator_code: p.operator_code, name: p.name,
                          status: 'available', price: p.price, currency: p.currency, product_id: p.id

           encrypted_data = v.encrypted_sensitive_data(value: Utils.random_pin(10))
           v.value = encrypted_data[:value]
           v.default_key_label = encrypted_data[:key_label]
           v.save_changes
           # sleep 0.5
         rescue Exception => e
           puts "#{e.class} #{e.message}"
        end
      end
      puts
    end

    puts
    puts 'Setting product quantities'
    puts '---------------------------'

    Product.order(:name).all.each do |p|
      quantity = Voucher.where(name: p.name, status: 'available').count
      puts "Setting #{p.name} quantity => #{quantity}"
      p.update quantity: quantity
    end

    puts
    puts 'Summary:'
    puts '---------------------------'
    puts "Voucher operators: #{Operator.where(type: 'voucher').count}"
    puts "Vouchers: #{Voucher.count}"
  end
end

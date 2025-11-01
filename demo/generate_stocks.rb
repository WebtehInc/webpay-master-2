require_relative 'demo_helper'

class GenerateStocks < Demo

  def test_generate_stocks

    puts 'Generating voucher stocks:'
    puts '---------------------------'

    VoucherStock.dataset.delete

    # :id, :account_id, :name, :quantity, :sales_count, :last_purchase_quantity, :last_purchase_at, :active,
    # :created_at, :updated_at, :product_id, :operator_code, :notify_quantity
    Account.where(type: 'business').all.each do |acc|
      puts "=> generating voucher stock for account ##{acc.id}"
      Product.all.each do |p|
        puts "stock for #{p.name}"
        acc.add_voucher_stock name: p.name, operator_code: p.operator_code, product_id: p.id,
                              active: true, notify_quantity: 10, account_id: acc.id, quantity: 50 + rand(100)
      end
    end

    puts
    puts 'Summary:'
    puts '---------------------------'
    puts "Voucher stocks: #{VoucherStock.count}"

  end

end

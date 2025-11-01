WebPay.route('buy-voucher') do |r|
  r.post do
    authorize!
    puts '=> buying voucher ...'
    BuyVoucher.call(self)
  end
end
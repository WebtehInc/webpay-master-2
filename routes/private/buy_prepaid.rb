WebPay.route('buy-prepaid') do |r|
  r.post do
    authorize!
    puts '=> buying prepaid voucher ...'
    BuyPrepaid.call(self)
  end
end
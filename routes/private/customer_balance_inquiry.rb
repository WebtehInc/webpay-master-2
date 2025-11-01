WebPay.route('customer-balance-inquiry') do |r|
  r.post do
    puts '=> customer balance inquiring ...'
    CustomerBalanceInquiry.call(self)
  end
end
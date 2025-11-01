WebPay.route('pay-bill') do |r|
  r.post do
    authorize!
    puts '=> paying bill ...'
    PayBill.call(self)
  end
end
WebPay.route('logout') do |r|
  r.post do
    puts '=> logging out ...'
    Logout.call(self)
  end
end
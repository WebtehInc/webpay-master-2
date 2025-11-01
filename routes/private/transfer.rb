WebPay.route('transfer') do |r|
  authorize!

  r.post 'wallet-to-bank' do
    puts ' => transfering from wallet to bank account ...'
    WalletToBankTransfer.call(self)
  end

  r.post 'bank-to-wallet' do
    puts ' => transfering from bank to wallet account ...'
    BankToWalletTransfer.call(self)
  end

  r.post 'bank-to-bank' do
    puts ' => transfering from bank to bank account ...'
    BankToBankTransfer.call(self)
  end

  r.post 'bank-balance-inquiry' do
    puts ' => balance inquiry for bank account ...'
    BankBalanceInquiry.call(self)
  end

  r.post do
    puts '=> transfering from wallet to wallet account ...'
    WalletToWalletTransfer.call(self)
  end
end
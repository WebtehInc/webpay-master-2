WebPay.route('terminals') do |r|

  account_ids = User[user_id].accounts.reduce([]){|ids, account| ids << account[:id] }
  terminals = Terminal.dataset.where(account_id: account_ids)

  r.on ':id' do |id|
    puts '=> getting terminal ...'
    terminal =  terminals.where(id: id).first

    # r.get 'changes' do
    #   puts '=> getting terminal changes ...'
    #   Audit.where(model_id: terminal[:id], model_name: 'Terminal').reverse(:id).limit(5).all
    # end

    r.get 'cashiers' do
      puts '=> getting terminal cashiers ...'
      terminal.cashiers_dataset.order(:full_name).all
    end

    r.post 'cashiers/create' do
      puts '=> creating cashier ...'
      CreateCashier.call(terminal[:id], self)
    end

    r.post 'cashiers/:id/change-pin' do |id|
      puts '=> generating new pin for cashier ...'
      cashier = terminal.cashiers_dataset.where(id: id).first
      new_pin =  Utils.random_pin(4)
      cashier.update(hashed_pin: Digest::SHA512.hexdigest(new_pin))
      {pin: new_pin}
    end

    r.post 'cashiers/:id' do |id|
      puts '=> updating cashier ...'
      UpdateCashier.call(terminal.cashiers_dataset.where(id: id).first[:id], self)
    end

    # r.post do
    #   authorize!
    #   puts '=> updating terminal ...'
    #   UpdateTerminal.call(terminal[:id], self)
    # end
  end

  # r.get do
  #   puts '=> getting terminals for account ...'
  #   terminals.all
  # end

end
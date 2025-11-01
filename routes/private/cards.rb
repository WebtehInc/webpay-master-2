WebPay.route('cards') do |r|

  r.on ':id' do |id|
    card =  Card.where(user_id: user_id, id: id).first
    card_id = card.try(:id)

    r.post 'toggle-active-flag' do
      puts '=> toggle active flag ...'
      Card.update(card_id, {active: !card.active}, user_id)&.public_values
    end

    r.post 'change-pin' do
      puts '=> changing card pin ...'
      ChangeCardPin.call(card_id, self)
    end
  end

  r.post do
    puts '=> getting cards ...'
    Card.select(*Card::PUBLIC_ATTRS).where(user_id: user_id).all
  end
end

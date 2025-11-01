require_relative 'demo_helper'

class GenerateCards < Demo

  def test_generate_cards

    puts 'Generating cards:'
    puts '---------------------------'
    User.all.each_with_index do |user, index|
      begin
        pan         = "#{BIN}#{user.id}"
        masked_pan  = "#{BIN}000****#{user.id}"
        card        = Card.create(user_id: user.id, first_name: user.first_name, last_name: user.last_name, active: true, pin_block: PIN_BLOCK,
                                  bin: BIN, pan: pan, masked_pan: masked_pan, hashed_pan: Digest::SHA512.hexdigest(pan),
                                  exp_month: Time.now.month, exp_year: Time.now.year + 1, type: 'tag', serial_number: "#{user.id}#{rand(1000)}", cmk: "123", cmk_kcv: "456")

        puts "##{index}: #{user.first_name} #{user.last_name} - #{card.pan}"
        puts
      rescue Interrupt => e
        puts "\nTerminated manually."
        exit
      rescue Exception => e
        puts "failed for user ##{user.id}"
        puts "#{e.class} #{e.message}"
      end
    end

    puts
    puts 'Summary:'
    puts '---------------------------'
    puts "Users: #{User.count}"
    puts "Cards: #{Card.count}"
  end

end

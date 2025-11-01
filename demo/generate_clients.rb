require_relative 'demo_helper'

class GenerateClients < Demo

  def test_generate_clients

    puts 'Generating clients:'
    puts '---------------------------'
    ARGV[0].to_i.times do |n|
      n = n + 1
      country = COUNTRY_CODES.sample
      first_name = Faker::Name.first_name
      last_name = Faker::Name.last_name
      email = Faker::Internet.safe_email(first_name)
      birth_date = Faker::Date.between(60.years.ago, 18.years.ago)
      password = PASSWORD
      city = Faker::Address.city
      address = Faker::Address.street_address
      zip = Faker::Address.zip
      phone = rand(9999999999)
      title = ['mr', 'ms'].sample
      begin # duplicate email
        user = signup_user  email: email, first_name: first_name, password: password, city: city, zip: zip,
                            phone: phone, last_name: last_name, birth_date: birth_date, address: address,
                            country: country, title: title, terms: true
        Message.create(title: 'Welcome to eWallet!', body: 'You can reply to this message.', user_id: user.id)
        puts "##{n}: #{user.first_name} #{user.last_name} - #{user.email}"
        puts
      rescue
        puts 'Email exists!'
      end
    end

    puts
    puts 'Summary:'
    puts '---------------------------'
    puts "Clients: #{User.count}"
    puts "Messages: #{Message.count}"
  end

end


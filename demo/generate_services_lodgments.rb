require_relative 'demo_helper'

class GenerateServicesLodgments < Demo

  def test_generate_services_lodgments

    puts 'Generating services lodgments:'
    puts '---------------------------'

    terminals = Terminal.all

    terminals.each do |t|

      cashier_pin = Utils.random_pin(4)
      if cashier = t.cashiers.last
        cashier.hashed_pin = Digest::SHA512.hexdigest(cashier_pin)
        cashier.save
      end

      digest = Utils.digest_SHA512(t.terminal_key, t.access_token, t.services_batch_number)
      puts "=> closing batch on terminal ##{t.id}"
      post '/api/close-services-batch', { access_token: t.access_token, digest: digest,
                                          api_version: '1.0.0.', application_version: '1.0.0.',
                                          services_batch_number: t.services_batch_number,
                                          cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json rescue 'Failed!'
    end

    puts
    puts 'Summary:'
    puts '---------------------------'
    puts "ServicesLodgment: #{ServicesLodgment.count}"

  end

end

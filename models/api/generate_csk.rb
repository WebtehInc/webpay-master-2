class GenerateCSK < DStruct::DStruct

  attributes  strings:  [:access_token, :digest, :api_version, :application_version, :card_serial, :card_challenge]

  def self.call(context)

    input = new(context.params)

    # models
    terminal = Terminal.where(access_token: input.access_token).first
    card = Card.where(serial_number: input.card_serial).last

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :terminal, terminal
        option :card,  card
        option :input, input

        def valid_terminal?(value)
          terminal && terminal.active
        end

        def valid_digest?(value)
          terminal && value == Digest::SHA512.hexdigest(terminal.terminal_key.to_s + terminal.access_token.to_s + input.card_serial.to_s +  + input.card_challenge.to_s)
        end

        def valid_card_serial?(value)
          card && card.active
        end
      end

      # echoed
      key(:api_version)         { filled? }
      key(:application_version) { filled? }

      # fields
      key(:access_token)    { filled? & valid_terminal? }
      key(:digest)          { filled? & valid_digest? }
      key(:card_serial)     { filled? & valid_card_serial? }
      key(:card_challenge)  { filled? }

    end

    input.add_validation_schema validation_schema

    if input.valid?

      session_keys = InfoSwitch::MifareApi.new.session_key_exchange(
        InfoSwitch.api_keys('Terminal', terminal.access_token).
          merge(card: card, card_challenge: input.card_challenge)
      )

      if session_keys['error']
        context.render_error('crypto_error' => session_keys['error'])

      else
        ccr = session_keys['card_challenge_response']
        csk = session_keys['csk_pos']
        kcv = session_keys['csk_kcv']

        # calculate digest
        digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + ccr.to_s + csk.to_s + kcv.to_s)
        context.render_success({api_version: input.api_version,
          application_version: input.application_version,
          digest: digest,
          ccr: ccr,
          csk: csk,
          kcv: kcv})

      end

    else
      context.render_error(input.errors)
    end
  end

end

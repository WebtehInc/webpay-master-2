class ApiDownloadFile < DStruct::DStruct

  attributes  strings:  [:access_token, :digest, :api_version, :application_version, :file_name]

  def self.call(context)

    input = new(context.params)

    # models
    terminal = Terminal.where(access_token: input.access_token).first
    account  = Account.where(id: terminal.try(:account_id)).first

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :terminal, terminal
        option :account, account
        option :input, input

        def valid_digest?(value)
          terminal && value == Digest::SHA512.hexdigest(terminal.terminal_key.to_s + terminal.access_token.to_s + input.file_name)
        end

        def exists?(value)
          true
        end

        def valid_terminal?(value)
          terminal
        end
      end

      # echoed
      key(:api_version)         { filled? }
      key(:application_version) { filled? }

      # fields
      key(:access_token)  { filled? & valid_terminal? }
      key(:digest)        { filled? & valid_digest? }
      key(:file_name)     { filled? & exists? }
    end

    input.add_validation_schema validation_schema

    if input.valid?
      file = open("downloads/#{input.file_name}", 'rb')
      context.response.headers.merge!( "Content-Type" => 'application/octet-stream' )
      context.response.status = 200
      context.response.write file.read
      file.close
      context.request.halt
    else
      context.render_error(input.errors)
    end
  end
end

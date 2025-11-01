class ApiReverseOnTimeout < DStruct::DStruct

  attributes  strings:  [:access_token, :digest, :api_version, :application_version, :systan, :transaction_type],
              integers: [:amount]

  TYPE_MAPPER = { bill_mpos: 'bill-payment',
                  voucher_mpos: 'sell-voucher',
                  top_up_mpos: 'top-up',
                  sale_wallet_mpos: 'sale-wallet',
                  prepaid_mpos: 'sell-prepaid'}.invert

  def self.call(context)

    input = new(context.params)

    # models
    terminal  = Terminal.where(access_token: input.access_token).first
    account   = Account .where(id: terminal&.account_id).first

    # validation
    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :terminal, terminal
        option :account, account
        option :input, input
        option :type_mapper, :type_mapper

        include CommonTerminalValidators
        def valid_digest?(value)
          terminal && value == Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, input.systan, input.transaction_type)
        end

        def valid?(value)
          TYPE_MAPPER[value]
        end
      end

      # echoed
      key(:api_version)         { filled? }
      key(:application_version) { filled? }

      # required
      key(:access_token)        { filled? & valid_terminal? }
      key(:digest)              { filled? & valid_digest? }
      key(:transaction_type)    { filled? & valid? }
      key(:systan)              { filled? }
      key(:amount)              { int? }
    end

    input.add_validation_schema validation_schema

    if input.valid?
      Reversal.create({account_id: account.id, terminal_id: terminal.id, systan: input.systan, transaction_type: TYPE_MAPPER[input.transaction_type],
                      amount: input.amount, currency: account.currency, services_batch_number: terminal.services_batch_number,
                      api_version: input.api_version, application_version: input.application_version})

      context.render_success(message: 'reversal is saved')
    else
      context.render_error(input.errors)
    end
  end
end

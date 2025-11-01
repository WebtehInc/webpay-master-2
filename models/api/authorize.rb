require_relative 'common_terminal_validators'

class Authorize < DStruct::DStruct

  attributes  strings:  [:access_token, :digest, :api_version, :application_version, :cashier_pin,
                          :systan, :currency, :number_of_installments, :transaction_type],
              integers: [:amount, :cashier_id],
              times:    [:client_datetime]

  def self.call(context)
    input = new(context.params.except(:card_data, :conversion_currency, :conversion_rate, :converted_amount))

    # models
    terminal = Terminal.where(access_token: input.access_token).first
    cashier  = Cashier.where( hashed_pin: Digest::SHA512.hexdigest(input.cashier_pin.to_s), id: input.cashier_id,
                              active: true, terminal_id: terminal.try(:id)).first
    account  = Account.where(id: terminal.try(:account_id)).first

    # validation
    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :terminal, terminal
        option :account, account
        option :input, input
        option :account, account
        option :cashier, cashier

        # card data validation
        option :card_data, context.params[:card_data]
        option :conversion_currency, context.params[:conversion_currency]
        option :conversion_rate, context.params[:conversion_rate]
        option :converted_amount, context.params[:converted_amount]

        include CommonTerminalValidators

        def enabled_service?(value)
          account && account.card_authorization
        end

        def valid_digest?(value)
          terminal &&
          value == Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, input.systan, input.amount, input.currency)
        end

        def over_min_amount?(value)
          account && account.min_amount < value
        end

        def below_max_amount?(value)
          account && account.max_amount > value
        end

        def valid_currency?(value)
          account && value == account.currency
        end

        def valid_card?(value)
          value
        end

        def valid_card_data_amount?(value)
          return valid_converted_amount?(value) if conversion?
          card_data[:amount] == value
        end

        def valid_converted_amount?(value)
          card_data[:amount] == (value * conversion_rate.to_f).to_i
        end

        def valid_card_data_currency?(value)
          return valid_conversion_currency?(value) if conversion?
          card_data[:currency] == CURRENCY_CODES[value]
        end

        def valid_conversion_currency?(value)
          card_data[:currency] != CURRENCY_CODES[value] && CURRENCY_CODES.keys.include?(value)
        end

        def conversion?
          [conversion_currency, conversion_rate, converted_amount].any?
        end
      end

      # echoed
      key(:api_version)         { filled? }
      key(:application_version) { filled? }

      # required
      key(:access_token)      { filled? & valid_terminal? & enabled_service? & working_time? }
      key(:digest)            { filled? & valid_digest? }
      key(:amount)            { int? & over_min_amount? & below_max_amount? & valid_card_data_amount? }
      key(:currency)          { filled? & valid_currency? & valid_card_data_currency? }
      key(:transaction_type)  { filled? & inclusion?(CARD_TRANSACTION_TYPES.keys.stringify) }
      key(:systan)            { filled? }
      key(:client_datetime)   { filled? }
      key(:cashier_pin)       { filled? & valid_cashier? }
      key(:cashier_id)        { int? }
    end

    input.add_validation_schema validation_schema

    if input.valid?
      api_and_app_versions = {api_version: input.api_version, application_version: input.application_version}
      trx_type = input.transaction_type

      types_mapper = {
        card_authorization: [:authorize,  :credit],
        card_sale:          [:sale,       :credit],
        card_capture:       [:capture,    :credit],
        card_refund:        [:refund,     :debit],
        card_void:          [:void,       :debit],
        card_reversal:      [:reverse,    :debit],
        card_adjustment:    [:adjustment, :credit]
      }

      # process input
      acquirer_data = CardAuthorization.send(types_mapper[trx_type.to_sym][0], terminal, context.params)

      t = nil
      DB.transaction do
        # we must be pesimistic here
        account.lock!

        # credit merchant
        t = Transaction.create({
          account_id: account.id, terminal_id: terminal.id,
          type: types_mapper[trx_type.to_sym][1].to_s,
          transaction_type: trx_type, cashier_id: cashier.id,
          description: "##{input.systan}: #{acquirer_data['response_code']} #{acquirer_data['reference_number']}",
          systan: input.systan, amount: input.amount,
          currency: input.currency, balance: 0,
          client_datetime: input.client_datetime}
            .merge(api_and_app_versions)
            .merge(acquirer_data.slice('status', 'response_code', 'response_message', 'approval_code', 'reference_number'))
        )
      end # end DB transaction

      digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + input.systan)
      output = {id: t.id,
                digest: digest,
                cashier: cashier.full_name}
                  .merge(api_and_app_versions)
                  .merge(acquirer_data: acquirer_data)

      # render all responses as 200
      context.render_success(output)

    # input validation failed
    else
      context.render_error(input.errors)
    end
  end
end

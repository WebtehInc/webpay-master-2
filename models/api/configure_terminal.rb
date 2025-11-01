require_relative "helpers/download_config"

class ConfigureTerminal < DStruct::DStruct
  attributes strings: [:access_token, :digest, :api_version, :application_version]

  def self.call(context)
    configure_terminal = new(context.params)

    # models
    terminal = Terminal.where(access_token: configure_terminal.access_token).first
    account = terminal&.account

    # validation
    validation_schema = Dry::Validation.Form do
      configure do
        config.messages_file = Pathname(__dir__).join("../errors.yml")
        option :terminal, terminal

        def valid_terminal?(value)
          terminal && terminal.active
        end

        def valid_digest?(value)
          terminal && value == Digest::SHA512.hexdigest(terminal.terminal_key.to_s + terminal.access_token.to_s)
        end
      end

      # echoed
      key(:api_version) { filled? }
      key(:application_version) { filled? }

      # required
      key(:access_token) { filled? & valid_terminal? }
      key(:digest) { filled? & valid_digest? }
    end

    configure_terminal.add_validation_schema validation_schema

    # response
    if configure_terminal.valid?

      # we must be pesimistic here
      terminal.lock!

      # fetch new session keys & the InfoSwitch terminal parameters
      infoswitch_attrs = InfoSwitch::PosApi.new.configure_terminal(
        { application_version: configure_terminal.application_version }.
          merge(InfoSwitch.api_keys("Terminal", terminal.access_token))
      )

      # get relations for operators and available vouchers
      operators = Operator.select(:name, :code, :currency, :type, :info).where(active: true).order(:name)
      vouchers = DB[:voucher_stocks___s].where(s__account_id: terminal.account_id).join(:products, id: :product_id).
        select(:s__name, :s__quantity, :s__operator_code, :currency, :price).order(:price, :s__name).all

      # calcualte digest
      digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + terminal.config_version.to_s)

      # build response
      # hack with json parse/to_json because values.to_json doesnt convert json serialized attrs ie .accepted_cards
      context.render_success JSON.parse(terminal.to_json(only: [:merchant_name, :merchant_address, :merchant_address, :merchant_phone, :tid, :mid,
                                                                :default_currency, :accepted_currencies, :accepted_cards, :number_of_installments, :receipt_text,
                                                                :config_version, :services_batch_number])).
                               merge(currency_codes: CURRENCY_CODES.slice(*terminal.accepted_currencies),
                                     wallet_to_card_types: CardAuthorization::TYPES_MAPPER).
                               merge(min_amount: account.min_amount,
                                     max_amount: account.max_amount).
                               merge(terminal_id: terminal.id,
                                     vouchers: vouchers,
                                     digest: digest,
                                     api_version: configure_terminal.api_version,
                                     application_version: configure_terminal.application_version,
                                     operators: operators,
                                     payment_methods: MPOS_PAYMENT_METHODS_AND_TYPES,
                                     cashiers: Cashier.select(:id, :full_name, :manager).where(active: true, terminal_id: terminal.id).order(:full_name)).
                               merge(services: {
                                       sell_vouchers: account.sell_vouchers,
                                       sell_prepaids: account.sell_prepaids,
                                       bill_payments: account.bill_payments,
                                       top_up: account.top_up,
                                       card_authorization: account.card_authorization,
                                       sale_wallet: account.sale_wallet,
                                     }.merge(service_flags(account))).
                               merge(infoswitch: infoswitch_attrs).
                               merge(downloads: DownloadConfig.call)
    else
      context.render_error(configure_terminal.errors)
    end
  end

  def self.service_flags(account)
    {
      service_curgas: !!CurgasService::HOST_URL && account.service_curgas,
      # TODO: use flag from `account.service_tax`
      service_tax: !!TaxService::HOST_URL && true,
    }
  end
end

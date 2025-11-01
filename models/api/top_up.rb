class TopUp < DStruct::DStruct
  attributes strings: [:access_token, :digest, :api_version, :application_version, :systan, :card_number, :currency, :cashier_pin, :card_pin, :account_number, :payment_method, :payment_method_type],
             integers: [:amount, :cashier_id],
             times: [:client_datetime]

  def self.call(context)

    # non existent keys
    context.params[:card_pin] = false unless context.params[:card_pin]
    context.params[:card_number] = false unless context.params[:card_number]
    context.params[:account_number] = false unless context.params[:account_number]

    input = new(context.params)

    # merchant account
    terminal = Terminal.where(access_token: input.access_token).first
    cashier = Cashier.where(hashed_pin: Utils.digest_SHA512(input.cashier_pin), id: input.cashier_id, active: true, terminal_id: terminal.try(:id)).first
    account = Account.where(id: terminal.try(:account_id)).first

    # user and his account - fetch them via card or account_number
    if context.params[:card_number] # we cannot use input.card_number because it is casted to 'false'
      card = Card.where(hashed_pan: Utils.digest_SHA512(input.card_number)).first
      user = card&.user
      wallet_account = user&.accounts_dataset&.where(default: true, currency: input.currency)&.first
    elsif context.params[:account_number]
      wallet_account = Account.where(account_number: input.account_number, currency: input.currency).first
      user = wallet_account&.users&.first
    end

    # validation
    validation_schema = Dry::Validation.Form do
      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join("../errors.yml")
        option :terminal, terminal
        option :input, input
        option :card, card
        option :wallet_account, wallet_account
        option :account, account
        option :cashier, cashier
        option :context, context

        include CommonTerminalValidators

        def enabled_service?(value)
          account&.top_up
        end

        def valid_digest?(value)
          terminal && value == Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, (context.params[:card_number] || context.params[:account_number]),
                                                   input.amount, input.currency, input.systan)
        end

        def valid_target_account?(value)
          wallet_account && wallet_account&.active
        end

        def valid_card?(value)
          card&.active
        end

        def valid_pin?(value)
          card&.pin_block == value
        end

        def unique?(value)
          terminal && !Transaction.where(terminal_id: terminal.id, systan: value, services_batch_number: terminal.services_batch_number).first
        end
      end

      # echoed
      key(:api_version) { filled? }
      key(:application_version) { filled? }

      # required
      key(:access_token) { filled? & valid_terminal? & enabled_service? & working_time? }
      key(:digest) { filled? & valid_digest? }

      key(:amount) { int? & over_min_amount? & below_max_amount? & under_credit_limit? }
      key(:currency) { filled? }
      key(:account_number) { filled? & valid_target_account? } if context.params[:account_number]
      key(:card_number) { filled? & valid_target_account? & valid_card? } if context.params[:card_number]
      key(:card_pin) { filled? & valid_pin? } if context.params[:card_pin]

      key(:systan) { filled? & unique? }
      key(:client_datetime) { filled? }
      key(:cashier_pin) { filled? & valid_cashier? }
      key(:cashier_id) { int? }
      key(:payment_method) { filled? & inclusion?(ApiHelpers::PAYMENT_METHODS) & valid_payment_method_type? }
      key(:payment_method_type) { empty? | inclusion?(ApiHelpers::PAYMENT_METHOD_TYPES) }
    end

    input.add_validation_schema validation_schema

    api_and_app_versions = { api_version: input.api_version, application_version: input.application_version }

    if input.valid?
      new_account_balance = account.balance # + input.amount # we dont use balance but exposure
      new_wallet_account_balance = wallet_account.balance + input.amount

      merchant_trx = nil
      DB.transaction do

        # we must be pesimistic here
        account.lock!
        wallet_account.lock!
        card.lock! if context.params[:card_number]

        # merchant record, pagafasil credit
        merchant_trx = Transaction.create({ account_id: account.id, terminal_id: terminal.id, systan: input.systan,
                                            cashier_id: cashier.id, type: "credit", status: "approved", transaction_type: "top_up_mpos",
                                            description: "Top-up ##{account.account_number}", balance: new_account_balance,
                                            amount: input.amount, currency: input.currency, services_batch_number: terminal.services_batch_number,
                                            payment_method: input.payment_method, payment_method_type: input.payment_method_type }.merge(api_and_app_versions))

        # update merchant account
        # account.update(balance: Sequel.+(:balance, input.amount))
        account.update(exposure_amount: Sequel.+(:exposure_amount, input.amount))

        # update terminal batch amount
        terminal.update({ batch_amount: Sequel.+(:batch_amount, input.amount) })

        # credit user
        user_trx = Transaction.create(account_id: wallet_account.id, user_id: user.id,
                                      type: "credit", status: "approved", transaction_type: "top_up",
                                      description: "Top-up at #{terminal.merchant_name}", balance: new_wallet_account_balance,
                                      amount: input.amount, currency: input.currency, parent_id: merchant_trx.id)
        wallet_account.update(balance: Sequel.+(:balance, input.amount))

        # update card
        card.update(access_count: Sequel.+(:access_count, 1), last_access_at: Time.now, last_access_terminal_id: terminal.id) if context.params[:card_number]
      end

      # build response
      response = { id: merchant_trx.id,
                   digest: Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, merchant_trx.id),
                   cashier: cashier.full_name }.merge(api_and_app_versions)

      ApiHelpers.cache_response(input, response)
      context.render_success(response)
    else
      context.render_error(input.errors)
    end
  end
end

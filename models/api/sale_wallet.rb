require_relative "common_terminal_validators"

class SaleWallet < DStruct::DStruct
  attributes strings: [:access_token, :digest, :api_version, :application_version,
                       :systan, :card_number, :card_pin, :currency, :cashier_pin],
             integers: [:amount, :cashier_id],
             times: [:client_datetime]

  def self.call(context)
    input = new(context.params)

    # merchant account
    terminal = Terminal.where(access_token: input.access_token).first
    cashier = Cashier.where(hashed_pin: Digest::SHA512.hexdigest(input.cashier_pin.to_s), id: input.cashier_id,
                            active: true, terminal_id: terminal.try(:id)).first
    merchant_account = Account.where(id: terminal.try(:account_id)).first

    # user account
    card = Card.where(hashed_pan: Digest::SHA512.hexdigest(input.card_number.to_s)).first
    user = card&.user
    wallet_account = user&.accounts_dataset&.where(default: true, currency: input.currency)&.first

    # validation
    validation_schema = Dry::Validation.Form do
      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join("../errors.yml")
        option :terminal, terminal
        option :input, input
        option :card, card
        option :wallet_account, wallet_account
        option :merchant_account, merchant_account
        option :cashier, cashier
        option :account, merchant_account

        include CommonTerminalValidators

        # target account limits validation
        target_limit_critria = { account_type: wallet_account&.type, user_type: user&.type, transaction_type: "sale_wallet", currency: wallet_account&.currency, debit_or_credit: "debit", active: true }
        option :target_user_limits, Limit.where(target_limit_critria.merge(user_id: user&.id)).where { valid_until > Time.now }.to_hash_groups(:type)
        option :target_global_limits, Limit.where(target_limit_critria.merge(user_id: nil)).to_hash_groups(:type)
        option :target_account_user, user
        option :target_account, wallet_account
        option :amount, input.amount
        option :transaction_type, "sale_wallet"
        option :target_account_debit_or_credit, "debit"
        include LimitsValidation::TargetAccountLimitsValidation

        def enabled_service?(value)
          merchant_account && merchant_account.sale_wallet
        end

        def valid_digest?(value)
          terminal && value == Digest::SHA512.hexdigest(
            terminal.terminal_key.to_s + terminal.access_token.to_s + input.card_number.to_s +
            input.amount.to_s + input.currency.to_s + input.systan.to_s
          )
        end

        def over_min_amount?(value)
          merchant_account && value > 0 && merchant_account.min_amount < value
        end

        def below_max_amount?(value)
          merchant_account && merchant_account.max_amount > value
        end

        def valid_target_account?(value)
          wallet_account
        end

        def available_funds?(value)
          wallet_account && wallet_account.balance > value
        end

        def valid_card?(value)
          card&.active
        end

        def valid_pin?(value)
          card&.pin_block == value
        end
      end

      # echoed
      key(:api_version) { filled? }
      key(:application_version) { filled? }

      # required
      key(:access_token) { filled? & valid_terminal? & enabled_service? & working_time? }
      key(:digest) { filled? & valid_digest? }

      key(:amount) { int? & over_min_amount? & below_max_amount? & available_funds? & target_account_under_count_limit? & target_account_under_volume_limit? }
      key(:currency) { filled? }
      key(:card_number) { filled? & valid_target_account? & valid_card? }
      key(:card_pin) { filled? & valid_pin? }

      key(:systan) { filled? }
      key(:client_datetime) { filled? }
      key(:cashier_pin) { filled? & valid_cashier? }
      key(:cashier_id) { int? }
    end

    input.add_validation_schema validation_schema

    api_and_app_versions = { api_version: input.api_version, application_version: input.application_version }

    if input.valid?
      new_merchant_account_balance = merchant_account.balance + input.amount
      new_wallet_account_balance = wallet_account.balance - input.amount

      merchant_trx = nil
      DB.transaction do

        # we must be pesimistic here
        merchant_account.lock!
        wallet_account.lock!
        card.lock!

        # merchant credit trx
        merchant_trx = Transaction.create(account_id: merchant_account.id, terminal_id: terminal.id, systan: input.systan,
                                          cashier_id: cashier.id, type: "credit", status: "approved", transaction_type: "sale_wallet_mpos",
                                          description: "Sale to ##{wallet_account.account_number}", balance: new_merchant_account_balance,
                                          amount: input.amount, currency: input.currency, services_batch_number: terminal.services_batch_number)

        # credit merchant account
        merchant_account.update(balance: Sequel.+(:balance, input.amount))

        # update terminal batch amount
        terminal.update({ batch_amount: Sequel.+(:batch_amount, input.amount) })

        # user debit trx
        user_trx = Transaction.create(account_id: wallet_account.id, user_id: user.id,
                                      type: "debit", status: "approved", transaction_type: "sale_wallet",
                                      description: "Payment at #{terminal.merchant_name}", balance: new_wallet_account_balance,
                                      amount: input.amount, currency: input.currency, parent_id: merchant_trx.id)
        # debit user account
        wallet_account.update(balance: Sequel.-(:balance, input.amount))

        # update card
        card.update(access_count: Sequel.+(:access_count, 1), last_access_at: Time.now, last_access_terminal_id: terminal.id)
      end

      # build response
      response = { id: merchant_trx.id,
                   digest: Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + merchant_trx.id.to_s),
                   cashier: cashier.full_name }.merge(api_and_app_versions)

      ApiHelpers.cache_response(input, response)
      context.render_success(response)
    else
      context.render_error(input.errors)
    end
  end
end

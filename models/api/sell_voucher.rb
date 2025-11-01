class SellVoucher < DStruct::DStruct
  attributes strings: [:name, :access_token, :digest, :api_version, :application_version, :systan,
                       :payment_method, :payment_method_type, :cashier_pin],
             times: [:client_datetime],
             integers: [:cashier_id]

  def self.call(context)
    input = new(context.params)

    # models
    terminal = Terminal.where(access_token: input.access_token).first
    cashier = Cashier.where(hashed_pin: Digest::SHA512.hexdigest(input.cashier_pin.to_s), id: input.cashier_id,
                            active: true, terminal_id: terminal.try(:id)).first
    account = Account.where(id: terminal.try(:account_id)).first

    voucher = Voucher.select(:id, :name, :price, :status, :value, :operator_code).where(name: input.name, status: "available").order(:id).limit(20).all.sample
    stock = VoucherStock.where(name: input.name, account_id: account.try(:id), active: true).where { quantity > 0 }.first
    operator = voucher.try(:operator)

    # validation
    validation_schema = Dry::Validation.Form do
      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join("../errors.yml")
        option :terminal, terminal
        option :voucher, voucher
        option :operator, operator
        option :input, input
        option :account, account
        option :cashier, cashier
        option :stock, stock

        include CommonTerminalValidators

        def enabled_service?(value)
          account && account.sell_vouchers
        end

        def valid_digest?(value)
          terminal && value == Digest::SHA512.hexdigest(
            terminal.terminal_key.to_s + terminal.access_token.to_s +
            input.name.to_s + input.systan.to_s
          )
        end

        # NOTE: unknown voucher - invalid name input OR out of global stock
        def valid_voucher?(value)
          voucher && voucher.price > 0
        end

        def on_stock?(value)
          stock
        end
      end

      # echoed
      key(:api_version) { filled? }
      key(:application_version) { filled? }

      # required
      key(:access_token) { filled? & valid_terminal? & enabled_service? & working_time? }
      key(:digest) { filled? & valid_digest? }

      key(:name) { filled? & on_stock? & valid_voucher? & valid_operator? } # check operator at end because voucher is not set if out of stock
      key(:systan) { filled? }
      key(:client_datetime) { filled? }
      key(:cashier_pin) { filled? & valid_cashier? }
      key(:cashier_id) { int? }
      key(:payment_method) { filled? & inclusion?(ApiHelpers::PAYMENT_METHODS) & valid_payment_method_type? }
      key(:payment_method_type) { empty? | inclusion?(ApiHelpers::PAYMENT_METHOD_TYPES) }
    end

    input.add_validation_schema validation_schema

    api_and_app_versions = { api_version: input.api_version, application_version: input.application_version }

    if input.valid?

      # decript voucher
      decrypted_voucher_value = voucher.decrypted_sensitive_data[:value]

      # send email notifications
      begin
        # notify bank
        product = voucher.product
        quantity = Voucher.where(name: input.name, status: "available").count
        Mailer.sendmail("/app/voucher_low_stock", product) if (quantity - 1) == product.notify_quantity

        # notify merchant
        if account&.settings["low_stock"]
          Mailer.sendmail("/merchant/voucher_low_stock", account, stock) if account.merchant_email and (stock.quantity - 1) == account.settings["low_stock"][input.name]
        end
      rescue => error
        puts "EMAIL FAILED: #{error.class} => #{error.message}"
      end

      t = nil
      DB.transaction do

        # account.lock!
        voucher.lock!
        stock.lock!
        terminal.lock!

        # trx values
        new_batch_amount = terminal.batch_amount + voucher.price
        new_balance = account.balance # + voucher.price

        #### debit merchant
        t = Transaction.create({
          account_id: account.id, terminal_id: terminal.id, systan: input.systan,
          type: "credit", status: "approved", transaction_type: "voucher_mpos", cashier_id: cashier.id,
          description: "Voucher: #{voucher.name}", balance: new_balance, operator_code: voucher.operator_code,
          note: "Batch balance: #{new_batch_amount / 100.0} #{account.currency}", voucher_id: voucher.id,
          amount: voucher.price, currency: account.currency, services_batch_number: terminal.services_batch_number,
          client_datetime: input.client_datetime, payment_method: input.payment_method,
          payment_method_type: input.payment_method_type,
        }.merge(api_and_app_versions))

        # account.update(balance: Sequel.+(:balance, voucher.price))

        # update terminal batch amount
        terminal.update({ batch_amount: Sequel.+(:batch_amount, voucher.price) })

        # sell voucher
        voucher.update status: "sold", terminal_id: terminal.id

        # update stock
        stock.update({ quantity: Sequel.-(:quantity, 1) })
      end

      # build response
      response = { id: t.id,
                   voucher_code: decrypted_voucher_value,
                   voucher_serial: voucher.uid,
                   digest: Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + decrypted_voucher_value),
                   cashier: cashier.full_name }.merge(api_and_app_versions)

      ApiHelpers.cache_response(input, response)
      context.render_success(response)
    else
      context.render_error(input.errors)
    end
  end
end

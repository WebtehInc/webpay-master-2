class CloseServicesBatch < DStruct::DStruct
  attributes strings: [:access_token, :digest, :api_version, :application_version, :services_batch_number, :cashier_pin],
             integers: [:cashier_id]

  def self.call(context)
    input = new(context.params)

    # models
    terminal = Terminal.where(access_token: input.access_token).first
    manager = Cashier.where(hashed_pin: Utils.digest_SHA512(input.cashier_pin), id: input.cashier_id,
                            manager: true, active: true, terminal_id: terminal.try(:id)).first
    account = Account.where(id: terminal.try(:account_id)).first

    # validation
    validation_schema = Dry::Validation.Form do
      configure do
        config.messages_file = Pathname(__dir__).join("../errors.yml")
        option :terminal, terminal
        option :manager, manager
        option :account, account

        def valid_terminal?(value)
          terminal && terminal.active && account && account.active
        end

        def valid_digest?(value)
          terminal && value == Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, terminal.services_batch_number)
        end

        def valid_manager?(value)
          manager
        end

        def not_empty_batch?(value)
          terminal && terminal.transactions.count > 0
        end
      end

      # echoed
      key(:api_version) { filled? }
      key(:application_version) { filled? }

      # required
      key(:access_token) { filled? & valid_terminal? }
      key(:digest) { filled? & valid_digest? }
      key(:services_batch_number) { filled? & int? & not_empty_batch? }
      key(:cashier_pin) { filled? & valid_manager? }
      key(:cashier_id) { int? }
    end

    input.add_validation_schema validation_schema

    # response
    if input.valid?
      new_services_batch_number = terminal.services_batch_number + 1

      DB.transaction do
        terminal.lock!
        account.lock!

        closing_time = Time.now

        transactions_per_cashier_for_trx_type = Proc.new do |trx_type|
          DB[:transactions___t].join(:cashiers___c, id: :cashier_id)
            .where(t__services_batch_number: terminal.services_batch_number,
                   t__terminal_id: terminal.id, voided: false,
                   t__transaction_type: trx_type)
            .select_group(:c__full_name)
            .select_append { sum(:t__amount).as(:total) }
            .select_append { count(:t__id).as(:count) }
            .order(:c__full_name)
        end

        transactions_per_operator_for_trx_type = Proc.new do |trx_type|
          DB[:transactions___t]
            .join(:operators___o, code: :operator_code)
            .where(t__services_batch_number: terminal.services_batch_number,
                   t__terminal_id: terminal.id, voided: false,
                   t__transaction_type: trx_type)
            .select_group(:o__name)
            .select_append { sum(:t__amount).as(:total) }
            .select_append { count(:t__id).as(:count) }
            .order(:o__name)
        end

        transactions_per_payment_method_for_trx_type = Proc.new do |trx_type|
          DB[:transactions]
            .where(services_batch_number: terminal.services_batch_number,
                   terminal_id: terminal.id, transaction_type: trx_type)
            .select_group(:payment_method).
            select_append { sum(:amount).as(:total) }
            .select_append { count(:id).as(:count) }
            .order(:payment_method)
        end

        #################### totals + subtotals
        # totals
        totals = DB[:transactions]
          .where(
            services_batch_number: terminal.services_batch_number, terminal_id: terminal.id, voided: false,
            transaction_type: ["service_mpos", "bill_mpos", "voucher_mpos", "top_up_mpos", "sale_wallet_mpos", "prepaid_mpos"],
          )
          .select_group(:transaction_type)
          .select_append { sum(:amount).as(:total) }
          .select_append { count(:id).as(:count) }.order(:transaction_type)

        # reversals
        reversals = DB[:transactions]
          .where(
            services_batch_number: terminal.services_batch_number,
            terminal_id: terminal.id, voided: true,
          )
          .select_group(:transaction_type)
          .select_append { sum(:amount).as(:total) }
          .select_append { count(:id).as(:count) }
          .order(:transaction_type)

        # bills
        bills_per_payment_method = transactions_per_payment_method_for_trx_type.call("bill_mpos")
        bills_per_operator = transactions_per_operator_for_trx_type.call("bill_mpos")
        bills_per_cashier = transactions_per_cashier_for_trx_type.call("bill_mpos")

        # vouchers
        vouchers_per_payment_method = transactions_per_payment_method_for_trx_type.call("voucher_mpos")
        vouchers_per_operator = transactions_per_operator_for_trx_type.call("voucher_mpos")
        vouchers_per_cashier = transactions_per_cashier_for_trx_type.call("voucher_mpos")

        # prepaids
        prepaids_per_payment_method = transactions_per_payment_method_for_trx_type.call("prepaid_mpos")
        prepaids_per_operator = transactions_per_operator_for_trx_type.call("prepaid_mpos")
        prepaids_per_cashier = transactions_per_cashier_for_trx_type.call("prepaid_mpos")

        # services
        services_per_payment_method = transactions_per_payment_method_for_trx_type.call("service_mpos")
        services_per_operator = transactions_per_operator_for_trx_type.call("service_mpos")
        services_per_cashier = transactions_per_cashier_for_trx_type.call("service_mpos")

        # topups
        top_ups_per_cashier = transactions_per_cashier_for_trx_type.call("top_up_mpos")

        # wallet sales
        wallet_sales_per_cashier = transactions_per_cashier_for_trx_type.call("sale_wallet_mpos")

        # net total
        net_total = totals.reduce({ total: 0, count: 0 }) do |net_total, total|
          if %w(top_up_mpos sale_wallet_mpos).include? total[:transaction_type]
            net_total[:total] = net_total[:total] - total[:total]
          else
            net_total[:total] = net_total[:total] + total[:total]
          end
          net_total[:count] = net_total[:count] + total[:count]
          net_total
        end

        #################### voucher stock
        voucher_stock = DB[:voucher_stocks___s]
          .where(s__account_id: terminal.account_id)
          .join(:products, id: :product_id)
          .select(:s__name, :s__quantity, :s__operator_code, :currency, :price, (Sequel[:s__quantity] * Sequel[:price]).as(:amount))
          .order(:price, :s__name).all

        grouped_voucher_stock = voucher_stock
          .reduce({}) { |acc, op| acc.update op[:operator_code] => { operator_code: op[:operator_code], quantity: 0, amount: 0, vouchers: [] } }

        voucher_stock.each do |stock|
          operator = grouped_voucher_stock[stock[:operator_code]]
          operator[:quantity] = operator[:quantity] + stock[:quantity]
          operator[:amount] = operator[:amount] + stock[:amount]
          operator[:vouchers] << stock
        end

        #################### create new lodgement
        lodgment = ServicesLodgment.create(
          terminal_id: terminal.id,
          account_id: account.id,
          cashier_id: manager.id,
          currency: terminal.default_currency,
          batch_number: terminal.services_batch_number,
          batch_amount: terminal.batch_amount,
          started_at: terminal.services_batch_start_date,
        )

        #################### open new batch on terminal
        terminal.update({ services_batch_number: Sequel.+(:services_batch_number, 1),
                          services_batch_start_date: closing_time,
                          batch_amount: 0 })

        #################### build response
        context.render_success({
          services_batch_number: new_services_batch_number,
          digest: Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, new_services_batch_number),
          api_version: input.api_version,
          application_version: input.application_version,
          cashier: manager.full_name,
          starting_time: lodgment.started_at,
          closing_time: closing_time,

          # voucher_stock
          voucher_stock: grouped_voucher_stock.values,

          # totals
          totals: totals.all,
          net_total: net_total,
          reversals: reversals.all,

          # totals breakdown
          bills: {
            per_payment_method: bills_per_payment_method.all,
            per_operator: bills_per_operator.all,
            per_cashier: bills_per_cashier.all,
          },
          vouchers: {
            per_payment_method: vouchers_per_payment_method.all,
            per_operator: vouchers_per_operator.all,
            per_cashier: vouchers_per_cashier.all,
          },
          prepaids: {
            per_payment_method: prepaids_per_payment_method.all,
            per_operator: prepaids_per_operator.all,
            per_cashier: prepaids_per_cashier.all,
          },
          services: {
            per_payment_method: services_per_payment_method.all,
            per_operator: services_per_operator.all,
            per_cashier: services_per_cashier.all,
          },
          top_ups: { per_cashier: top_ups_per_cashier.all },
          wallet_sales: { per_cashier: wallet_sales_per_cashier.all },
        })
      end
    else
      context.render_error(input.errors)
    end
  end
end

class BuyVoucher < DStruct::DStruct

  attributes strings: [:name, :account_id]

  def self.call(context)

    user = User[context.user_id]
    buy_voucher = new(context.params)

    # models
    account = user.accounts_dataset.where(id: buy_voucher.account_id, type: WALLET_ACCOUNT_TYPES.keys.stringify).first
    voucher = Voucher.where(name: buy_voucher.name, status: 'available',  currency: account.try(:currency)).order(:id).limit(20).all.sample
    product = voucher.try(:product)
    operator = voucher.try(:operator)

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = './models/errors.yml'
        option :account,  account
        option :voucher,  voucher
        option :operator, operator

        # limits validation
        limit_critria = { account_type: account&.type, user_type: user&.type, transaction_type: 'voucher', currency: account&.currency, debit_or_credit: 'debit', active: true }
        option :user,                 user
        option :source_user_limits,   Limit.where(limit_critria.merge(user_id: user.id)).where{valid_until > Time.now}.to_hash_groups(:type)
        option :source_global_limits, Limit.where(limit_critria.merge(user_id: nil)).to_hash_groups(:type)
        option :source_account,       account
        option :amount,               voucher&.price
        option :transaction_type,     'voucher'
        include LimitsValidation::SourceAccountLimitsValidation

        def valid_source_account?(value)
          account
        end

        def available_funds?(value)
          account && account.balance > voucher.price
        end

        def valid_voucher?(value)
          voucher && voucher.price > 0
        end

        def valid_operator?(value)
          operator && operator.active
        end
      end

      key(:name)        { filled? & valid_voucher? & valid_operator? & available_funds? & valid_source_account? & under_count_limit? & under_volume_limit? }
      key(:account_id)  { filled? & numeric? & valid_source_account? }
    end

    buy_voucher.add_validation_schema validation_schema


    if buy_voucher.valid?

      # decript voucher
      voucher_value = voucher.decrypted_sensitive_data[:value]

      # send low stock email
      begin
        quantity = Voucher.where(name: buy_voucher.name, status: 'available').count
        Mailer.sendmail('/app/voucher_low_stock', product) if quantity == product.notify_quantity
      rescue => error
        puts "EMAIL FAILED: #{error.class} => #{error.message}"
      end

      # api output
      api_output = {'Name': voucher.name, 'Code': voucher_value.in_groups_by(4), 'Serial': voucher.uid}

      DB.transaction do

        # we must be pesimistic here
        account.lock!
        voucher.lock!

        new_balance = account.balance - voucher.price

        # debit user
        Transaction.create( account_id: buy_voucher.account_id, user_id: user.id, operator_code: voucher.operator_code,
                            type: 'debit', status: 'approved', transaction_type: 'voucher', voucher_id: voucher.id,
                            description: "#{voucher.name}", balance: new_balance,
                            amount: voucher.price, currency: account.currency, note: api_output.to_desc)
        account.update(balance: Sequel.-(:balance, voucher.price))

        # credit operator
        # TODO

        # sell voucher
        voucher.update status: 'sold'
      end

      voucher_info = (product.info.to_s.size > 0 ? product.info : operator.info)
      context.render_success(api_output.merge('Info': voucher_info))
    else
      context.render_error(buy_voucher.errors)
    end
  end
end

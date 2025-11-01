WebPay.route('accounts') do |r|

  r.on ':id' do |id|
    account = User[user_id].accounts_dataset.where(id: id).first
    account_id = account.try(:id)

    r.post 'create'  do
      authorize!
      puts '=> creating account ...'
      CreateAccount.call(self)
    end

    r.post 'update' do
      authorize!
      puts '=> updating account ...'
      UpdateAccount.call(account_id, self)
    end

    r.post 'set-default' do
      puts '=> setting default account ...'

      valid_default_types = WALLET_ACCOUNT_TYPES.keys.stringify
      render_error(message: 'Invalid account ype') if !valid_default_types.include?(account.type)

      # set this one to default
      Account.update(account_id, {default: true}, user_id)

      # unset previous
      previous_default = User[user_id].accounts_dataset.where({default: true, type: valid_default_types}).exclude(:id => account_id).first
      Account.update(previous_default.id, {default: false}, user_id).type if previous_default
    end

    r.post 'settings/update' do
      puts '=> updating account setings...'
      Account[account_id].update(settings: params)
      params
    end

    r.post 'services-lodgments/:id/show' do |id|
      puts '=> getting services lodgment ...'
      trxs_ds = DB[:transactions].where(account_id: account_id, services_batch_number: params[:services_batch_number], terminal_id: params[:terminal_id])

      bill_reversal_trxs =  trxs_ds.where(voided: true,
                                        operator_code: Operator.where(type: 'bill').select_hash(:code, :name).keys).
                                        group_and_count(:operator_code).
                                        select_append{sum(:amount).as(:amount)}

      bill_trxs = trxs_ds.where(# voided: false,
                        operator_code: Operator.where(type: 'bill').select_hash(:code, :name).keys).
                        exclude(transaction_type: 'bill_reversal_mpos').
                        group_and_count(:operator_code).
                        select_append{sum(:amount).as(:amount)}

      voucher_trxs = DB[:vouchers___v].join(:transactions___t, voucher_id: :id).where(
                                t__services_batch_number: params[:services_batch_number],
                                t__terminal_id: params[:terminal_id], t__voided: false).
                                select_group(:v__name).
                                select_append{sum(:t__amount).as(:amount)}.
                                select_append{count(:t__id).as(:count)}.order(:v__name)

      topup_trxs    = trxs_ds.where(transaction_type: 'top_up_mpos')
      prepaid_trxs  = trxs_ds.where(transaction_type: 'prepaid_mpos')

      service_trxs_group_per_attr_with_excluded_types = Proc.new do |service, grouping_attr, excluded_types, join, order|
        ds = DB[:transactions___t]
        ds = ds.join(join[:relation], join[:attrs]) if join
        order = order ? order : grouping_attr
        ds.where( t__services_batch_number: params[:services_batch_number],
                  t__terminal_id: params[:terminal_id], # voided: false,
                  t__operator_code: Operator.where(type: service).select_hash(:code, :name).keys).
                  exclude(excluded_types).
                  select_group(grouping_attr).
                  select_append{sum(:t__amount).as(:amount)}.
                  select_append{count(:t__id).as(:count)}.order(order)
      end

      { bill_trxs: bill_trxs.all,
        bill_reversal_trxs: bill_reversal_trxs.all,
        voucher_trxs: voucher_trxs.all,
        topup_trxs: {amount: topup_trxs.sum(:amount), count: topup_trxs.count},
        prepaid_trxs: {amount: prepaid_trxs.sum(:amount), count: prepaid_trxs.count},

        bills_per_payment_method: service_trxs_group_per_attr_with_excluded_types.call(
          'bill',
          :t__payment_method,
          {t__transaction_type: 'bill_reversal_mpos'}).all,

        bills_per_payment_method_type: service_trxs_group_per_attr_with_excluded_types.call(
          'bill',
          :t__payment_method_type,
          {t__transaction_type: 'bill_reversal_mpos'}).all,

        bills_per_cashier: service_trxs_group_per_attr_with_excluded_types.call(
          'bill',
          :c__full_name,
          {t__transaction_type: 'bill_reversal_mpos'},
          {relation: :cashiers___c, attrs: {id: :cashier_id}},
          :c__full_name
          ).all
      }
    end

    r.post 'services-lodgments/:page' do |page, criteria|
      puts '=> geting services lodgments...'
      r.paginated_dataset(*ServicesLodgment.paginate(page, {account_id: account_id}, params[:search])).to_json(include:
      { terminal: {only: [:id, :merchant_name]},
        account: {only: [:account_number, :credit_limit, :merchant_name]},
        cashier: {only: [:full_name]}})
    end

    r.get 'terminals' do
      Terminal.select(*Terminal::PUBLIC_ATTRS).where(account_id: account_id).all
    end

    r.get do
      puts '=> getting account ...'
      account.values
    end
  end

  # all for home page
  r.get do
    User[user_id].accounts_dataset.order(:id).to_json include: :voucher_stocks
  end
end

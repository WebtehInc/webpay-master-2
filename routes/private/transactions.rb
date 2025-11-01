WebPay.route("transactions") do |r|
  puts "=> getting transactions ..."

  account_ids = User[user_id].accounts.reduce([]) { |ids, account| ids << account[:id] }

  r.post ":page" do |page, criteria|
    # NOTE: fix leaky references when filtering by account_id
    # default scope of {account_id: my_account_ids} would be replaced
    # with {account_id = params[:search][:account_id]} in WHERE clause
    # it could probably be fixed with sequel
    if params.dig(:search, :account_id)
      account_id = params[:search].delete(:account_id) # delete it
      account_ids = [account_id] if account_ids.include?(account_id) # this is actual filter now
    end
    r.paginated_dataset(*Transaction.paginate(page, { account_id: account_ids }, params[:search]))
      .to_json(include: { account: { only: [:account_number, :type] }, cashier: { only: [:full_name] } })
  end

  r.get "transfer-history" do
    puts "=> getting transfer history ..."

    last_20_debit_transfers_ids = Transaction.select(:id).where(user_id: user_id, transaction_type: "transfer", type: "debit").limit(20)
    last_10_credited_accounts_ids = Transaction.select(:account_id).distinct().
      where(transaction_type: "transfer", type: "credit", parent_id: last_20_debit_transfers_ids).
      limit(10).select_map(:account_id)

    Account.where({ id: last_10_credited_accounts_ids }).to_json(
      only: Account::PUBLIC_ATTRS,
      include: { users: { only: [:first_name, :last_name, :email, :phone] } },
    )
  end
end

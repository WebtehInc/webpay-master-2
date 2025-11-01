Sequel.migration do
  change do
    alter_table(:transactions) do
      add_index  :operator_code
      add_index  :voucher_id
      add_index  :cashier_id
      add_index  :admin_id
      add_index  :voided
    end

    alter_table(:audits) do
      add_index  :user_id
      add_index  :admin_id
      add_index  :model_name
    end

    alter_table(:login_trails) do
      add_index  :user_id
      add_index  :admin_id
    end

    alter_table(:services_lodgments) do
      add_index  :cashier_id
      add_index  :batch_amount
    end

    alter_table(:roles) do
      add_index  :admin_id
    end

    alter_table(:vouchers) do
      add_index  :revealed_by
    end

    alter_table(:terminals) do
      add_index  :access_token
      add_index  :trx_counter
    end

    alter_table(:accounts) do
      add_index  :credit_limit
      add_index  :account_number
      add_index  :merchant_name
    end

    alter_table(:voucher_stocks) do
      add_index  :quantity
      add_index  :last_purchase_at
    end

    alter_table(:users) do
      add_index  :last_name
      add_index  :email
      add_index  :type
    end
  end
end
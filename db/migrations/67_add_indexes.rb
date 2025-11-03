Sequel.migration do
  change do
    alter_table(:transactions) do
      add_index  :operator_code, if_not_exists: true
      add_index  :voucher_id, if_not_exists: true
      add_index  :cashier_id, if_not_exists: true
      add_index  :admin_id, if_not_exists: true
      add_index  :voided, if_not_exists: true
    end

    alter_table(:audits) do
      add_index  :user_id, if_not_exists: true
      add_index  :admin_id, if_not_exists: true
      add_index  :model_name, if_not_exists: true
    end

    alter_table(:login_trails) do
      add_index  :user_id, if_not_exists: true
      add_index  :admin_id, if_not_exists: true
    end

    alter_table(:services_lodgments) do
      add_index  :cashier_id, if_not_exists: true
      add_index  :batch_amount, if_not_exists: true
    end

    alter_table(:roles) do
      add_index  :admin_id, if_not_exists: true
    end

    alter_table(:vouchers) do
      add_index  :revealed_by, if_not_exists: true
    end

    alter_table(:terminals) do
      add_index  :access_token, if_not_exists: true
      add_index  :trx_counter, if_not_exists: true
    end

    alter_table(:accounts) do
      add_index  :credit_limit, if_not_exists: true
      add_index  :account_number, if_not_exists: true
      add_index  :merchant_name, if_not_exists: true
    end

    alter_table(:voucher_stocks) do
      add_index  :quantity, if_not_exists: true
      add_index  :last_purchase_at, if_not_exists: true
    end

    alter_table(:users) do
      add_index  :last_name, if_not_exists: true
      add_index  :email, if_not_exists: true
      add_index  :type, if_not_exists: true
    end
  end
end
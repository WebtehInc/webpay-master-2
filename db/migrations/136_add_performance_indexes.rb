Sequel.migration do
  up do
    puts "Adding performance indexes for date-range queries..."

    # CRITICAL: Transaction table compound indexes (highest volume table)
    # Enable efficient queries like: "Get account/terminal/user transactions for date range"
    alter_table(:transactions) do
      add_index [:account_id, :created_at], name: :idx_transactions_account_created
      add_index [:terminal_id, :created_at], name: :idx_transactions_terminal_created
      add_index [:user_id, :created_at], name: :idx_transactions_user_created
    end

    # HIGH: Audit trail timeline queries
    # Enable queries like: "Show audit history for model type over time"
    alter_table(:audits) do
      add_index [:model_name, :created_at], name: :idx_audits_model_created
    end

    # MEDIUM: Login history queries
    # Enable queries like: "Show login history for user/admin over time"
    alter_table(:login_trails) do
      add_index [:user_id, :created_at], name: :idx_login_trails_user_created
      add_index [:admin_id, :created_at], name: :idx_login_trails_admin_created
    end

    # MEDIUM: Active user/admin lookups with date filtering
    alter_table(:users) do
      add_index [:active, :created_at], name: :idx_users_active_created
    end

    alter_table(:admins) do
      add_index [:active, :created_at], name: :idx_admins_active_created
    end

    # MEDIUM: Terminal status queries per account
    alter_table(:terminals) do
      add_index [:account_id, :active], name: :idx_terminals_account_active
    end

    # MEDIUM: Voucher inventory queries by terminal and status
    alter_table(:vouchers) do
      add_index [:terminal_id, :status, :created_at], name: :idx_vouchers_terminal_status_created
    end

    # MEDIUM: Service lodgment queries by terminal over time
    alter_table(:services_lodgments) do
      add_index [:terminal_id, :created_at], name: :idx_services_lodgments_terminal_created
      add_index [:account_id, :batch_number], name: :idx_services_lodgments_account_batch
    end

    puts "Performance indexes added successfully!"
  end

  down do
    puts "Removing performance indexes..."

    alter_table(:transactions) do
      drop_index [:account_id, :created_at], name: :idx_transactions_account_created
      drop_index [:terminal_id, :created_at], name: :idx_transactions_terminal_created
      drop_index [:user_id, :created_at], name: :idx_transactions_user_created
    end

    alter_table(:audits) do
      drop_index [:model_name, :created_at], name: :idx_audits_model_created
    end

    alter_table(:login_trails) do
      drop_index [:user_id, :created_at], name: :idx_login_trails_user_created
      drop_index [:admin_id, :created_at], name: :idx_login_trails_admin_created
    end

    alter_table(:users) do
      drop_index [:active, :created_at], name: :idx_users_active_created
    end

    alter_table(:admins) do
      drop_index [:active, :created_at], name: :idx_admins_active_created
    end

    alter_table(:terminals) do
      drop_index [:account_id, :active], name: :idx_terminals_account_active
    end

    alter_table(:vouchers) do
      drop_index [:terminal_id, :status, :created_at], name: :idx_vouchers_terminal_status_created
    end

    alter_table(:services_lodgments) do
      drop_index [:terminal_id, :created_at], name: :idx_services_lodgments_terminal_created
      drop_index [:account_id, :batch_number], name: :idx_services_lodgments_account_batch
    end

    puts "Performance indexes removed successfully!"
  end
end

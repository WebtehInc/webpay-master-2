Sequel.migration do
  change do
    alter_table(:users) do
      add_column :login_count,            Integer, default: 0
      add_column :failed_login_count,     Integer, default: 0

      add_column :last_login_at,          DateTime
      add_column :last_login_attempt_at,  DateTime
      add_column :last_login_ip,          String

      add_column :active,                 FalseClass, default: false
      add_index [:active]

      add_column :activation_token,       String
      add_index [:activation_token]

      add_column :reset_password_token,   String
      add_index [:reset_password_token]
    end
  end
end
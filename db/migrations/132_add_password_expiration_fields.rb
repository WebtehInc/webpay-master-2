Sequel.migration do
  change do
    alter_table(:admins) do
      add_column :password_expiration_date, DateTime, default: Time.now + 3600 * 24 * 90
      add_column :password_history, String
    end
  end
end

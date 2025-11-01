Sequel.migration do
  change do
    alter_table(:products) do
      add_column :info, String
      add_column :quantity, Integer, default: 0
      add_column :notify_percentage, Integer, default: 10
      add_column :replenished_at, DateTime
    end
  end
end
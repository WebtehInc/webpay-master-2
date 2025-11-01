Sequel.migration do
  change do
    alter_table(:transactions) do
      add_column :client_datetime, DateTime
      add_column :acquirer, String
      add_column :gateway, String
    end
  end
end
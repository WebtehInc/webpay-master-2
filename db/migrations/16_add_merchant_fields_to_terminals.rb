Sequel.migration do
  change do
    alter_table(:terminals) do
      add_column :merchant_address, String
      add_column :merchant_phone,   String
      add_column :merchant_email,   String
      add_column :batch_limit,      Integer, default: 0
    end
  end
end
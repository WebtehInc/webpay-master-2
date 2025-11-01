Sequel.migration do
  change do
    alter_table(:accounts) do
      add_column :exposure, Integer, default: 0
      add_column :merchant_name,        String
      add_column :merchant_description, String
      add_column :merchant_address,     String
      add_column :merchant_phone,       String
      add_column :merchant_email,       String
      add_column :merchant_fax,         String
    end
  end
end
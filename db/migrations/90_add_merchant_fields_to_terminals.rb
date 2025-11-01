Sequel.migration do
  change do
    alter_table(:terminals) do
      add_column :merchant_fax,     String
      add_column :merchant_contact, String
    end
  end
end
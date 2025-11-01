Sequel.migration do
  change do
    alter_table(:accounts) do
      add_column :merchant_contact, String
    end
  end
end
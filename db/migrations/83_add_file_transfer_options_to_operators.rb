Sequel.migration do
  change do
    alter_table(:operators) do
      add_column :file_exchange_company_id, String
      add_column :file_exchange_institution_id, String
      add_column :file_exchange_reference_number, String
    end
  end
end

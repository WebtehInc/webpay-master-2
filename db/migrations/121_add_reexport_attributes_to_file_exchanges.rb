Sequel.migration do
  change do
    alter_table(:file_exchange_logs) do
      add_column :company_id, String
      add_column :file_reference_number, Integer
    end
  end
end

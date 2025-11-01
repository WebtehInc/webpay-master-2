Sequel.migration do
  change do
    alter_table(:file_exchange_logs) do

      drop_column :file_reference_number
      add_column :file_path, String

    end
  end
end

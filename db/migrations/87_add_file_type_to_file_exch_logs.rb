Sequel.migration do
  change do
    alter_table(:file_exchange_logs) do

      add_column :file_type, String

    end
  end
end

Sequel.migration do
  change do
    alter_table(:file_exchange_logs) do
      add_column :insert_count, Integer
      add_column :update_count, Integer
      add_column :time_elapsed, Integer
    end
  end
end
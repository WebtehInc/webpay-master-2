Sequel.migration do
  change do
    alter_table(:file_exchange_logs) do
      add_column :trx_min_id, Integer
      add_column :trx_max_id, Integer
      add_column :trx_count, Integer
      add_column :trx_sum_amount, Integer
    end
  end
end


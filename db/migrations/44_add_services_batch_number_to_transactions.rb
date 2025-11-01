Sequel.migration do
  change do
    alter_table(:transactions) do
      add_column  :services_batch_number, Integer, default: 0
      add_index   :services_batch_number
    end
  end
end
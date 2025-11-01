Sequel.migration do
  change do
    alter_table(:terminals) do
      add_column  :services_batch_number, Integer, default: 1
      add_index   :services_batch_number
    end
  end
end
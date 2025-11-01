Sequel.migration do
  change do
    alter_table(:terminals) do
      add_column  :services_batch_start_date, DateTime, null: false, default: Time.now
    end
  end
end
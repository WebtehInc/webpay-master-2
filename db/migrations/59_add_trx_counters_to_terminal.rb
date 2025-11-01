Sequel.migration do
  change do
    alter_table(:terminals) do
      add_column :batch_trx_counter,  Integer, default: 0
      add_column :trx_counter,        Integer, default: 0
    end
  end
end
Sequel.migration do
  change do
    alter_table(:terminals) do
      add_column :amount_limit, Integer, default: 0
      add_column :batch_amount, Integer, default: 0
    end
  end
end
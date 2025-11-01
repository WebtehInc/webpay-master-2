Sequel.migration do
  change do
    alter_table(:limits) do
      add_column :debit_or_credit, String, default: 'debit'
    end
  end
end

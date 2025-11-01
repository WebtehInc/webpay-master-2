Sequel.migration do
  change do
    alter_table(:transactions) do
      add_foreign_key :cashier_id, :cashiers, index: true
    end
  end
end
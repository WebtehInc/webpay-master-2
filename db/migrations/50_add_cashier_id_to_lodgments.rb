Sequel.migration do
  change do
    alter_table(:services_lodgments) do
      add_foreign_key :cashier_id, :cashiers, index: true
    end
  end
end
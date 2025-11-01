Sequel.migration do
  change do
    alter_table(:operators) do
      add_column :currency, String, null: false
    end
  end
end
Sequel.migration do
  change do
    alter_table(:transactions) do
      add_column :balance, Integer, null: false
    end
  end
end
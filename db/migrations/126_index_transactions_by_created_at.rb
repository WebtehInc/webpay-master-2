Sequel.migration do
  change do
    alter_table(:transactions) do
      add_index :created_at
    end
  end
end

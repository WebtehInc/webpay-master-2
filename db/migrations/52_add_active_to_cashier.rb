Sequel.migration do
  change do
    alter_table(:cashiers) do
      add_column :active, FalseClass, default: true
    end
  end
end
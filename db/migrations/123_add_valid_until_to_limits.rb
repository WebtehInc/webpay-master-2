Sequel.migration do
  change do
    alter_table(:limits) do
      add_column :valid_until, DateTime
    end
  end
end

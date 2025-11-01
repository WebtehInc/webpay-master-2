Sequel.migration do
  change do
    alter_table(:accounts) do
      add_column :default, FalseClass
      add_index [:default]
    end
  end
end

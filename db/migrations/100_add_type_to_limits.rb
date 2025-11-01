Sequel.migration do
  change do
    alter_table(:limits) do
      add_column :type, String
    end
  end
end
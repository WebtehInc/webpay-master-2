Sequel.migration do
  change do
    alter_table(:users) do
      add_column :type, String
    end
  end
end
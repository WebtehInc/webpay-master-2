Sequel.migration do
  change do
    alter_table(:accounts) do
      add_column :settings, String
    end
  end
end
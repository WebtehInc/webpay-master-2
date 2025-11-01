Sequel.migration do
  change do
    alter_table(:operators) do
      add_column :info, String
    end
  end
end
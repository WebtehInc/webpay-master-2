Sequel.migration do
  change do
    alter_table(:operators) do
      add_column :email, String
    end
  end
end

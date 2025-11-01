Sequel.migration do
  change do
    alter_table(:admins) do
      add_column :superuser, FalseClass, default: false
    end
  end
end
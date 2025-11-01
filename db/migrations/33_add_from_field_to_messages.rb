Sequel.migration do
  change do
    alter_table(:messages) do
      add_column :sender, String, default: 'admin'
    end
  end
end
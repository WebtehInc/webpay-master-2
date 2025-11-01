Sequel.migration do
  change do
    alter_table(:accounts) do
      add_column :type, String, default: 'personal'
      add_index  :type
    end
  end
end

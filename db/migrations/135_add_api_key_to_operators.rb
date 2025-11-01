Sequel.migration do
  change do
    alter_table(:operators) do
      add_column :api_key_hash, String
      add_index :api_key_hash
    end
  end
end

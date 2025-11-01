Sequel.migration do
  change do
    alter_table(:terminals) do
      add_column :session_keys, String, text: true
    end
  end
end
Sequel.migration do
  change do
    alter_table(:fees) do
      add_column :status, String, null: false
      add_column :type, String, null: false
    end
  end
end


Sequel.migration do
  change do
    alter_table(:accounts) do
      add_column :state, String, default: 'approved'
      add_index  :state
    end
  end
end

Sequel.migration do
  change do
    alter_table(:cards) do
      add_column :state, String, default: 'pending'
      add_index  :state
    end
  end
end

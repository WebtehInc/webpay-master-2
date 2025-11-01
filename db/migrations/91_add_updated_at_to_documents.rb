Sequel.migration do
  change do
    alter_table(:documents) do
      add_column :updated_at, DateTime, null: false
    end
  end
end


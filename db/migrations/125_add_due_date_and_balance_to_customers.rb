Sequel.migration do
  change do
    alter_table(:customers) do
      add_column :due_date, DateTime
      add_column :due_balance,  Integer, default: 0
    end
  end
end

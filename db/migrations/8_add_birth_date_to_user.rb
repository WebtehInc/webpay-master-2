Sequel.migration do
  change do
    alter_table(:users) do
      add_column :birth_date, Date
    end
  end
end
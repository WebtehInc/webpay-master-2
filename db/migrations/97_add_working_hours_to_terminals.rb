Sequel.migration do
  change do
    alter_table(:terminals) do
      add_column :opening_hours,    Integer, default: 0
      add_column :opening_minutes,  Integer, default: 0
      add_column :closing_hours,    Integer, default: 0
      add_column :closing_minutes,  Integer, default: 0
    end
  end
end
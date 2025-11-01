Sequel.migration do
  change do
    alter_table(:transactions) do
      add_column :note, String
    end
  end
end
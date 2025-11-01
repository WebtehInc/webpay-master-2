Sequel.migration do
  change do
    alter_table(:cards) do
      add_column :pan, String
      add_index  :pan
      add_column :exp_month, Integer
      add_column :exp_year, Integer
    end
  end
end

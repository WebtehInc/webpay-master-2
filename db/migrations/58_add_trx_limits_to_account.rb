Sequel.migration do
  change do
    alter_table(:accounts) do
      add_column :min_amount,  Integer, default: 1
      add_column :max_amount,  Integer, default: 100000
    end
  end
end
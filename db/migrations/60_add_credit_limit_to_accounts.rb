Sequel.migration do
  change do
    alter_table(:accounts) do
      add_column :credit_limit,  Integer, default: 0
    end
  end
end
Sequel.migration do
  change do
    alter_table(:accounts) do
      add_column :sale_wallet, FalseClass
    end
  end
end

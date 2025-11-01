Sequel.migration do
  change do
    drop_table(:customer_balances)
  end
end

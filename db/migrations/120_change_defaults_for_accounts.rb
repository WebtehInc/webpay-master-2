Sequel.migration do
  up do
    set_column_default :accounts, :sale_wallet, false
    set_column_default :accounts, :default, false
  end

  down do
  end
end

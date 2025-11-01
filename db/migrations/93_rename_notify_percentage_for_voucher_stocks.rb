Sequel.migration do
  change do
    alter_table(:voucher_stocks) do
      rename_column :notify_percentage, :notify_quantity
    end
  end
end
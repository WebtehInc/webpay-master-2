Sequel.migration do
  change do
    alter_table(:voucher_stocks) do
      add_column :notify_percentage, Integer, default: 10
    end
  end
end



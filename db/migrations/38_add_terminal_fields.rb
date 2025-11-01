Sequel.migration do
  change do
    alter_table(:terminals) do

      # billing
      add_column :bill_cash_amount,     Integer, default: 0
      add_column :bill_card_amount,     Integer, default: 0
      add_column :bill_check_amount,    Integer, default: 0

      # vouchers
      add_column :voucher_cash_amount,  Integer, default: 0
      add_column :voucher_card_amount,  Integer, default: 0
      add_column :voucher_check_amount, Integer, default: 0
    end
  end
end
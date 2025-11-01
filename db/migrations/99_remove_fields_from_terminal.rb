Sequel.migration do
  up do
    drop_column :terminals, :bill_card_amount
    drop_column :terminals, :bill_cash_amount
    drop_column :terminals, :bill_check_amount
    drop_column :terminals, :voucher_card_amount
    drop_column :terminals, :voucher_cash_amount
    drop_column :terminals, :voucher_check_amount
  end
  down do
    add_column :audits, :bill_card_amount, Integer
    add_column :audits, :bill_cash_amount, Integer
    add_column :audits, :bill_check_amount, Integer
    add_column :audits, :voucher_card_amount, Integer
    add_column :audits, :voucher_cash_amount, Integer
    add_column :audits, :voucher_check_amount, Integer
  end
end

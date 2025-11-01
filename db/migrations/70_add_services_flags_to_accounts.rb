Sequel.migration do
  change do
    alter_table(:accounts) do
      add_column :sell_vouchers,  FalseClass, default: false
      add_column :sell_prepaids,  FalseClass, default: false
      add_column :bill_payments,  FalseClass, default: false
      add_column :top_up,         FalseClass, default: false
      add_column :card_authorization, FalseClass, default: false
    end
  end
end
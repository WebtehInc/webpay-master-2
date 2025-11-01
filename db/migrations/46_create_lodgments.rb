Sequel.migration do
  change do
    create_table(:services_lodgments) do
      primary_key :id, unique: true

      # keys
      foreign_key :terminal_id, :terminals, index: true
      foreign_key :account_id,  :accounts,  index: true

      # fileds
      Integer :batch_number,          default: 0, index: true
      Integer :batch_amount,          default: 0
      Integer :batch_limit,           default: 0
      String  :currency,              null: false

      # billing
      Integer :bill_cash_amount,      default: 0
      Integer :bill_card_amount,      default: 0
      Integer :bill_check_amount,     default: 0

      # vouchers
      Integer :voucher_cash_amount,   default: 0
      Integer :voucher_card_amount,   default: 0
      Integer :voucher_check_amount,  default: 0

      # timestamps
      DateTime :started_at, null: false
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
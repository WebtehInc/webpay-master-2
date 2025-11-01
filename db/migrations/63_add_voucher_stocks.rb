Sequel.migration do
  change do
    create_table(:voucher_stocks) do
      primary_key :id, unique: true

      # keys
      foreign_key :account_id, :accounts, index: true

      # fields
      String    :name, null: false
      Integer   :quantity, default: 0
      Integer   :sales_count, default: 0

      Integer   :last_purchase_quantity, default: 0
      DateTime  :last_purchase_at

      TrueClass :active, default: true

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
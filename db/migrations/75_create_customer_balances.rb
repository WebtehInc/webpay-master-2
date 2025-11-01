Sequel.migration do
  change do
    create_table(:customer_balances) do
      Integer :customer_id, null: false, index: true

      # fields
      Integer :balance,   default: 0
      String  :currency,  null: false

      # timestamps
      DateTime :updated_at, null: false
    end
  end
end

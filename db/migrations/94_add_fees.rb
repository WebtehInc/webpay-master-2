Sequel.migration do
  change do
    create_table(:fees) do
      primary_key :id, unique: true

      String  :category,          null: false
      String  :account_type
      String  :user_type
      String  :transaction_type,  null: false
      Integer :amount,            null: false
      String  :currency,          null: false

      FalseClass :active, default: false

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
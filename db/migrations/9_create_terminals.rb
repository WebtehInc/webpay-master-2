Sequel.migration do
  change do
    create_table(:terminals) do
      primary_key :id, unique: true

      # fields
      foreign_key :account_id, :accounts, index: true

      String :access_token
      String :terminal_key
      String :merchant_name, index: true
      String :tid
      String :mid
      String :default_currency
      String :accepted_currencies
      String :accepted_cards
      String :number_of_installments
      String :receipt_text

      FalseClass :active, default: false

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
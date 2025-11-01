Sequel.migration do
  change do
    create_table(:reversals) do
      primary_key :id, unique: true

      # keys
      foreign_key :terminal_id, :terminals, index: true
      foreign_key :account_id,  :accounts,  index: true

      # fields
      String  :systan
      Integer :amount
      String  :currency
      String  :client_datetime
      String  :transaction_type, index: true
      Integer :services_batch_number

      String  :api_version
      String  :application_version

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end

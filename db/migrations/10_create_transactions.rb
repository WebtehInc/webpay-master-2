Sequel.migration do
  change do
    create_table(:transactions) do
      primary_key :id, unique: true

      # fields
      foreign_key :terminal_id, :terminals, index: true
      foreign_key :account_id,  :accounts,  index: true
      foreign_key :user_id,     :users,     index: true

      Integer :parent_id, index: true

      # request
      String :type, index: true
      String :api_version
      String :application_version
      String :tid
      String :mid

      String :systan
      String :entry_method

      Integer :amount
      String  :currency
      Integer :number_of_installments
      String  :transaction_type, index: true

      String :pan
      String :exp_date

      String :ch_authentication
      String :pin_block
      String :ch_name
      String :emv_data
      String :track1
      String :track2
      String :track3

      # response
      String :approval_code
      String :reference_number, index: true
      String :response_code
      String :response_message
      String :status, index: true

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
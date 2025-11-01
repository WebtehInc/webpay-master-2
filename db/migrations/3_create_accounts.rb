Sequel.migration do
  change do
    create_table(:accounts) do
      primary_key :id, unique: true

      # data
      String  :title,           null: false
      String  :iban,            null: false
      String  :account_number,  null: false
      String  :currency,        null: false
      Integer :balance,         default: 0

      FalseClass :active, default: true

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
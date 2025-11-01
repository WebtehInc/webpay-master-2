Sequel.migration do
  change do
    create_table(:products) do
      primary_key :id, unique: true

      # fields

      String  :name,      null: false,    index: true
      Integer :price,     default: 0,     index: true
      String  :currency,  null: false,    index: true
      String  :type,      default: 'voucher',  index: true
      String  :operator_code, null: false

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
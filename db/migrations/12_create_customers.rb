Sequel.migration do
  change do
    create_table(:customers) do
      primary_key :id, unique: true

      # fields
      foreign_key :operator_code, :operators, index: true, type: :text

      String    :number,  null: false
      Integer   :balance, default: 0
      TrueClass :active,  default: true

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
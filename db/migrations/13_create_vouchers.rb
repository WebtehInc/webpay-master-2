Sequel.migration do
  change do
    create_table(:vouchers) do
      primary_key :id, unique: true

      # fields
      foreign_key :operator_code, :operators, index: true, type: :text
      foreign_key :terminal_id,   :terminals, index: true

      Integer :uid,           default: 0
      String  :name,          null: false,    index: true
      String  :value,         null: false
      Integer :batch_number,  default: 0,     index: true
      String  :status,        default: true,  index: true

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
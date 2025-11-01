Sequel.migration do
  change do
    create_table(:devices) do
      primary_key :id, unique: true
      foreign_key :terminal_id, :terminals, index: true, unique: true

      String :type,           null: false
      String :product_model,  null: false
      String :product_code,   null: false
      String :serial_number,  null: false, unique: true
      String :failure_type,   default: ''
      String :comment,        text: true, default: ''
      String :status,         null: false


      # timestamps
      DateTime :assigned_at
      DateTime :removed_at

      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
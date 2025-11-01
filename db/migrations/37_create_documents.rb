Sequel.migration do
  change do
    create_table(:documents) do
      primary_key :id, unique: true
      foreign_key :user_id, :users, index: true

      # data
      String :type,     null: false
      String :status,   null: false, default: 'pending'
      String :comment,  text: true
      String :file_name
      String :file_type
      String :file_size
      String :file_path

      # timestamps
      DateTime :created_at, null: false
    end
  end
end
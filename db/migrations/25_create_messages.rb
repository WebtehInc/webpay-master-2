Sequel.migration do
  change do
    create_table(:messages) do
      primary_key :id, unique: true

      # keys
      Integer :user_id
      index   :user_id

      Integer :admin_id
      index   :admin_id

      Integer :parent_id
      index   :parent_id

      # data
      String :title,  null: false
      String :body,   null: false, text: true

      FalseClass :read_by_user,   default: false
      index :read_by_user

      FalseClass :read_by_admin,  default: false
      index :read_by_admin

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
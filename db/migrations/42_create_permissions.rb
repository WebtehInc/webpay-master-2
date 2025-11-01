Sequel.migration do
  change do
    create_table(:permissions) do
      primary_key :id, unique: true

      String :context,  null: false
      String :action,   null: false

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
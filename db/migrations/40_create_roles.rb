Sequel.migration do
  change do
    create_table(:roles) do
      primary_key :id, unique: true

      String :name,         null: false
      String :description,  null: false

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
Sequel.migration do
  change do
    create_table(:settings) do
      String :name, primary_key: true

      String :title,    null: false
      String :value,    null: false
      String :type,     null: false
      String :category, null: false

      String :description, null: false

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
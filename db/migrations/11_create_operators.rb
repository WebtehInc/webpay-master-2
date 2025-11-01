Sequel.migration do
  change do
    create_table(:operators) do
      String :code, primary_key: true

      # fields
      String    :name,    null: false
      String    :type,    null: false
      TrueClass :active,  default: true

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
Sequel.migration do
  change do
    create_table(:events) do
      primary_key :id, unique: true

      # data
      String :type,         null: false
      String :title,        null: false
      String :description,  text: true
      String :body,         text: true
      String :params,       text: true
      String :env,          text: true

      # timestamps
      DateTime :created_at, null: false
    end
  end
end
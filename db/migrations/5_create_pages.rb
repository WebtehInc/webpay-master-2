Sequel.migration do
  change do
    create_table(:pages) do
      primary_key :id, unique: true

      # data
      String  :title, null: false
      String  :body,  null: false, text: true
      String  :slug,  null: false
      index   [:slug]

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
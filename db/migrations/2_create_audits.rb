Sequel.migration do
  change do
    create_table(:audits) do
      primary_key :id, unique: true

      # keys
      String  :model_name,  null: false
      Integer :model_id,    null: false
      index   [:model_name, :model_id]

      # data
      Integer :changed_by,  null: false
      String  :diff,        null: false

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
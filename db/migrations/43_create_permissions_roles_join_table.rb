Sequel.migration do
  change do

    create_table(:permissions_roles) do
      foreign_key :permission_id, :permissions, null: false
      foreign_key :role_id, :roles,             null: false
      primary_key [:permission_id, :role_id]
      index       [:permission_id, :role_id]
    end

  end
end
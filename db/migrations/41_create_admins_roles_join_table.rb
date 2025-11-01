Sequel.migration do
  change do

    create_table(:admins_roles) do
      foreign_key :admin_id,  :admins,  null: false
      foreign_key :role_id,   :roles,   null: false
      primary_key [:admin_id, :role_id]
      index       [:admin_id, :role_id]
    end

  end
end
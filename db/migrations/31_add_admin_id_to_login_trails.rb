Sequel.migration do
  change do
    alter_table(:login_trails) do
      add_foreign_key :admin_id, :admins, index: true
    end
  end
end
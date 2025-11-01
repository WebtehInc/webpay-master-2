Sequel.migration do
  change do
    alter_table(:roles) do
      add_foreign_key :admin_id, :admins, index: true
    end
  end
end
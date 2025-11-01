Sequel.migration do
  change do
    alter_table(:audits) do
      add_foreign_key :user_id,   :users,  index: true
      add_foreign_key :admin_id,  :admins, index: true
    end
  end
end
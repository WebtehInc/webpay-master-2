Sequel.migration do
  change do
    alter_table(:transactions) do
      add_foreign_key :admin_id, :admins, index: true
    end
  end
end
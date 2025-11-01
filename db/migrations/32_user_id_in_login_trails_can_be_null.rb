Sequel.migration do
  up do
    drop_column :login_trails, :user_id
    alter_table(:login_trails) do
      add_foreign_key :user_id, :users, index: true
    end
  end
  down do
    # pass
  end
end
Sequel.migration do
  change do
    alter_table(:limits) do
      add_foreign_key :user_id,  :users
      add_index  :user_id
    end
  end
end

Sequel.migration do
  change do
    create_table(:accounts_users) do
      foreign_key :account_id,  :accounts,  null: false
      foreign_key :user_id,     :users,     null: false
      primary_key [:account_id, :user_id]
      index       [:account_id, :user_id]
    end

  end
end
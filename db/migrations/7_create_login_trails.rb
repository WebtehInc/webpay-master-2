Sequel.migration do
  change do
    create_table(:login_trails) do

      # keys
      primary_key :id, unique: true
      foreign_key :user_id, :users, index: true

      # data
      String :ip,               null: false
      String :user_agent,       null: false
      String :browser_name,     null: false
      String :browser_version,  null: false
      String :platform,         null: false

      # timestamps
      DateTime :created_at, null: false
    end
  end
end

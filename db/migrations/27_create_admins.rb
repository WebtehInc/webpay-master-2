Sequel.migration do
  change do
    create_table(:admins) do
      primary_key :id, unique: true

      # profile
      String :first_name, null: false
      String :last_name,  null: false

      # settings
      String :email,          null: false, unique: true
      String :phone,          null: false
      String :password_hash,  null: false

      # otp
      String :otp_code, null: false

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
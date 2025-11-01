Sequel.migration do
  change do
    create_table(:cards) do
      primary_key :id, unique: true

      # fields
      foreign_key :user_id, :users, index: true

      Integer     :bin
      String      :type,                           index: true
      String      :access_token,  unique:   true , index: true
      FalseClass  :active,        default:  false, index: true

      # access log
      Integer   :access_count,            default: 0
      Integer   :failed_access_count,     default: 0
      Integer   :last_access_terminal_id
      DateTime  :last_access_at

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end

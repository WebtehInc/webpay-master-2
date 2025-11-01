Sequel.migration do
  change do
    create_table(:cashiers) do
      primary_key :id, unique: true

      # keys
      foreign_key :terminal_id, :terminals, index: true, null: false

      # fields
      FalseClass  :manager,   default: false
      String      :full_name, null: false
      String      :pin,       null: false

      # timestamps
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
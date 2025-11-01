Sequel.migration do
  change do
    alter_table(:cards) do
      rename_column :access_token, :serial_number
    end
  end
end

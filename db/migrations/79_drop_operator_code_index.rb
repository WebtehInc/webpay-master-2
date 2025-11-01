Sequel.migration do
  change do
    alter_table(:customers) do
      drop_index :operator_code
    end
  end
end

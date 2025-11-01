Sequel.migration do
  change do
    alter_table(:customers) do
      drop_foreign_key [:operator_code], :name => :customers_operator_code_fkey
    end
  end
end

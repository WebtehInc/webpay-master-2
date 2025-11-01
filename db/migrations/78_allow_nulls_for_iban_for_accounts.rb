Sequel.migration do
  change do
    alter_table(:accounts) do
      set_column_allow_null :iban
    end
  end
end

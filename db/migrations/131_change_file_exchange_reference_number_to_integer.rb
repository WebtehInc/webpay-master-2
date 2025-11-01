Sequel.migration do
  change do
    alter_table(:operators) do
      set_column_type :file_exchange_reference_number, :Integer, using: 'file_exchange_reference_number::integer'
    end
  end
end

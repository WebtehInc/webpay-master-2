Sequel.migration do
  change do
    alter_table(:customers) do
      add_index [:operator_code, :number, :currency], unique: true
    end
  end
end

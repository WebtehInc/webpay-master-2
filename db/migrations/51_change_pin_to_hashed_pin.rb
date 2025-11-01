Sequel.migration do
  change do
    alter_table(:cashiers) do
      rename_column :pin, :hashed_pin
    end
  end
end
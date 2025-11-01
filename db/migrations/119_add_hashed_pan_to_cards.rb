Sequel.migration do
  change do
    alter_table(:cards) do
      add_column :hashed_pan, String
      add_index  :hashed_pan
    end
  end
end

Sequel.migration do
  change do
    alter_table(:cards) do
      add_column :masked_pan, String
    end
  end
end

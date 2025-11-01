Sequel.migration do
  change do
    alter_table(:accounts) do
      rename_column :exposure, :exposure_amount
      add_index :exposure_amount

      add_column :exposure_limit,  Integer, default: 0, index: true
    end
  end
end
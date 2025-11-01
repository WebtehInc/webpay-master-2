Sequel.migration do
  change do
    alter_table(:terminals) do
      add_column :exposure_amount,  Integer, default: 0, index: true
    end
  end
end
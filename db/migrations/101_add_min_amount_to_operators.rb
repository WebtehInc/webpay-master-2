Sequel.migration do
  change do
    alter_table(:operators) do
      add_column :min_amount, Integer, default: 100
    end
  end
end


Sequel.migration do
  change do
    alter_table(:vouchers) do
      add_unique_constraint [:uid]
    end
  end
end

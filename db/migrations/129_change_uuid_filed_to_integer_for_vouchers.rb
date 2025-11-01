Sequel.migration do
  change do
    alter_table(:vouchers) do
      set_column_type :uid, String
    end
  end
end

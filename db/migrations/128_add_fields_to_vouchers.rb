Sequel.migration do
  change do
    alter_table(:vouchers) do
      add_column :expiration_date, DateTime
      add_column :institution_id,  String
    end
  end
end

Sequel.migration do
  change do
    alter_table(:vouchers) do
      add_column :default_key_label,  String
    end
  end
end
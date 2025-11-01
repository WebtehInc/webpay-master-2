Sequel.migration do
  change do
    alter_table(:vouchers) do
      add_column :price,    Integer,  default: 0
      add_column :currency, String,   null: false
    end
  end
end
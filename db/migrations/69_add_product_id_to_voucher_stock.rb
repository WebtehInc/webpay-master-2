Sequel.migration do
  change do
    alter_table(:voucher_stocks) do
      add_foreign_key :product_id, :products
      add_index  :product_id

      add_column :operator_code, String
    end
  end
end
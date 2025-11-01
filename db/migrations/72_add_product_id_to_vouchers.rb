Sequel.migration do
  change do
    alter_table(:vouchers) do
      add_foreign_key :product_id, :products
      add_index  :product_id
    end
  end
end
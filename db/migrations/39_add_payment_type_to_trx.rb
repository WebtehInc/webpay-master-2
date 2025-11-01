Sequel.migration do
  change do
    alter_table(:transactions) do
      add_column :payment_method,       String
      add_column :payment_method_type,  String
      add_index  :payment_method
      add_index  :payment_method_type
    end
  end
end
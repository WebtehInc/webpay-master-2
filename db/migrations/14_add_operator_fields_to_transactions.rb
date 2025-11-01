Sequel.migration do
  change do
    alter_table(:transactions) do
      add_column      :customer_number, String
      add_foreign_key :operator_code,   :operators, index: true, type: :text, name: :operator_code
      add_foreign_key :voucher_id,      :vouchers,  index: true
    end
  end
end
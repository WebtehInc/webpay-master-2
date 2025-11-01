Sequel.migration do
  change do
    alter_table(:transactions) do
      add_column :voided,  FalseClass, default: false, index: true
    end
  end
end
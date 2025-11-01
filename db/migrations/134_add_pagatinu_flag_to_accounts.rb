Sequel.migration do
  change do
    alter_table(:accounts) do
      add_column :service_pagatinu, FalseClass, default: true
    end
  end
end

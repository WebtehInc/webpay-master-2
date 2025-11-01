Sequel.migration do
  change do
    alter_table(:accounts) do
      add_column :service_curgas, FalseClass, default: true
    end
  end
end

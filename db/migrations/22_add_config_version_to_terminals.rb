Sequel.migration do
  change do
    alter_table(:terminals) do
      add_column :config_version, Integer, default: 0
    end
  end
end
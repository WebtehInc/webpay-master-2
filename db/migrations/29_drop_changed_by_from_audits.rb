Sequel.migration do
  up do
    drop_column :audits, :changed_by
  end
  down do
    add_column :audits, :changed_by, Integer
  end
end
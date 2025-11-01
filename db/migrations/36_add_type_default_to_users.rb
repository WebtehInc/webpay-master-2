Sequel.migration do
  up do
    drop_column :users, :type
    add_column  :users, :type, String, default: 'personal'
  end

  down do
    drop_column :users, :type
    add_column  :users, :type, String
  end
end
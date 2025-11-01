Sequel.migration do
  up do
    set_column_default :users, :type, 'basic'
  end

  down do
  end
end
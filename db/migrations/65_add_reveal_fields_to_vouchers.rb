Sequel.migration do
  change do
    alter_table(:vouchers) do
      add_foreign_key :revealed_by, :admins,  index: true
      add_column :revealed_at, DateTime
      add_column :revealed, FalseClass, default: false
    end
  end
end


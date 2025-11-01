Sequel.migration do
  change do
    alter_table(:operators) do

      add_column :bank_account_number, String

    end
  end
end

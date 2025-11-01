Sequel.migration do
  change do
    alter_table(:accounts) do
      add_column :previous_exposure_amount,     Integer, default: 0
      add_column :last_exposure_amount_deposit, Integer, default: 0
    end
  end
end

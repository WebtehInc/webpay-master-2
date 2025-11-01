Sequel.migration do
  up do
    alter_table(:terminals) do
      add_unique_constraint [:access_token]
    end
  end

  down do
    alter_table(:terminals) do
      # DB specific, but not needed anyway
      # postgres: -- ALTER TABLE terminals DROP CONSTRAINT terminals_access_token_key;
      # drop_constraint(:terminals_access_token_key)
    end
  end
end
Sequel.migration do
  up do
    alter_table(:cards) do
      add_unique_constraint [:pan]
    end
  end

  down do
    alter_table(:cards) do
      # DB specific, but not needed anyway
      # postgres: -- ALTER TABLE terminals DROP CONSTRAINT cards_pan;
      # drop_constraint(:cards_pan)
    end
  end
end

Sequel.migration do
  change do
    alter_table(:audits) do
      add_column :model_string_id, String
      add_index  :model_string_id

      set_column_allow_null :model_id
    end
  end
end
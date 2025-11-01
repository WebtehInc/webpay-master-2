Sequel.migration do
  change do
    alter_table(:cards) do
      add_column :pin_block,  String

      add_column :first_name, String
      add_column :last_name,  String

      add_column :cmk,        String
      add_column :cmk_kcv,    String
    end
  end
end

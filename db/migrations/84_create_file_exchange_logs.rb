Sequel.migration do
  change do
    create_table(:file_exchange_logs) do
      primary_key :id

      String :operator_code

      String :file_name   # /tmp/ECNV20140303001
      Fixnum :file_reference_number
      DateTime :file_timestamp

      String :direction   # import / export
      String :sender_id   # PSBB, ECNV, ...
      String :receiver_id # PSBB, ECNV, ...
      String :status      # in_progress, processed, error, sending, sent

      DateTime :started_at
      DateTime :finished_at
      DateTime :sent_at
    end
  end
end

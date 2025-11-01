class Document < Sequel::Model
  many_to_one :user

  PUBLIC_ATTRS = [:type, :status, :comment, :created_at]

end
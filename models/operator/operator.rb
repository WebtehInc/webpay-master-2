class Operator < Sequel::Model
  unrestrict_primary_key

  one_to_many :vouchers,      primary_key: :code, key: :operator_code
  one_to_many :transactions,  primary_key: :code, key: :operator_code
  one_to_many :customers,     primary_key: :code, key: :operator_code

end
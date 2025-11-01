class VoucherStock < Sequel::Model

  many_to_one :account
  many_to_one :product

end
class Reversal < Sequel::Model

  PER_PAGE = 25

  many_to_one :account
  many_to_one :terminal
end

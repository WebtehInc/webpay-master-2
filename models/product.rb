class Product < Sequel::Model
  
  one_to_many :vouchers
  
end
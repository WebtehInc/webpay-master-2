class ServicesLodgment < Sequel::Model
  plugin :dirty

  many_to_one :terminal
  many_to_one :account
  many_to_one :cashier
  one_to_many :audits, key: :model_id, conditions: { model_name: 'ServicesLodgment' }, select: [:created_at, :diff]

  PUBLIC_ATTRS = self.columns rescue []

end

require_relative 'update'
require_relative 'update_cashier'
require_relative 'create_cashier'

class Terminal < Sequel::Model
  plugin :dirty
  plugin :serialization, :json, :accepted_cards, :accepted_currencies, :session_keys

  many_to_one :account
  one_to_many :cashiers
  one_to_many :transactions
  one_to_many :services_lodgments
  one_to_many :audits, key: :model_id, conditions: { model_name: 'Terminal' }, select: [:created_at, :diff]

  PUBLIC_ATTRS = self.columns - [:session_keys, :access_token, :terminal_key] rescue []

end
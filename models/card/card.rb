require_relative 'change_card_pin'

class Card < Sequel::Model

  plugin :dirty

  many_to_one :user
  one_to_many :audits, key: :model_id, conditions: { model_name: 'Card' }, select: [:created_at, :diff]

  PUBLIC_ATTRS = [:id, :type, :bin, :masked_pan, :exp_month, :exp_year, :first_name, :last_name, :active, :state, :last_access_at, :created_at]

  def public_values
    values.slice *PUBLIC_ATTRS
  end

end

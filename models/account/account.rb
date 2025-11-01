# require 'ibanizator'
require_relative 'update'

class Account < Sequel::Model

  self.plugin :dirty
  plugin :serialization, :json, :settings

  one_to_many :audits, key: :model_id, conditions: { model_name: 'Account' }, select: [:created_at, :diff]
  one_to_many :transactions
  one_to_many :voucher_stocks
  one_to_many :terminals
  one_to_many :services_lodgments
  many_to_many :users

  PUBLIC_ATTRS = [:account_number, :type, :title]

  def public_values
    values
  end

  # first default personal account
  def self.insert(user_id, context, opts = {})

    # title = opts.fetch(:title){ "#{WebPay.opts[:default_curency]} balance" }
    title = 'Simple personal account'
    currency = opts.fetch(:currency){ WebPay.opts[:default_curency] }

    account_number = generate_account_number
    # iban = generate_iban(account_number)

    User[user_id].add_account({ title: title,
                                type: 'personal',
                                currency: currency,
                                # iban: iban,
                                account_number: account_number,
                                default: true
                                })
  end

  # def self.generate_iban(account_number)
  #   ibanizator = Ibanizator.new
  #   ibanizator.calculate_iban country_code: :ch, bank_code: '12345678', account_number: account_number.to_s
  # end

  def self.generate_account_number
    (400000000 + rand(1000000000))
  end
end

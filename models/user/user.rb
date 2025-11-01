require 'bcrypt'
require 'rotp'

# public
require_relative 'login'
require_relative 'signup'
require_relative 'activate'
require_relative 'reset_password'

# private
require_relative 'logout'
require_relative 'login_trail'
require_relative 'verify_otp'
require_relative 'update'
require_relative 'upload_document'

# service transactions
require_relative 'service_transactions/buy_prepaid'
require_relative 'service_transactions/buy_voucher'
require_relative 'service_transactions/customer_balance_inquiry'
require_relative 'service_transactions/pay_bill'

# bank transactions
require_relative 'bank_transactions/bank_balance_inquiry'
require_relative 'bank_transactions/bank_to_bank_transfer'
require_relative 'bank_transactions/bank_to_wallet_transfer'
require_relative 'bank_transactions/wallet_to_bank_transfer'

# wallet transactions
require_relative 'wallet_to_wallet_transfer'

# limit validation
require_relative 'limits_validation'

class User < Sequel::Model

  plugin :dirty
  plugin :serialization, :json, :settings

  one_to_many :audits, key: :model_id, conditions: { model_name: 'User' }, select: [:created_at, :diff]
  one_to_many :login_trails
  one_to_many :transactions
  one_to_many :messages
  one_to_many :documents
  one_to_many :cards
  one_to_many :limits
  one_to_many :changes, key: :user_id, class: :Audit # all audit records made by this user
  many_to_many :accounts

  NON_PUBLIC_ATTRS = [:id, :password_hash, :otp_code, :active, :activation_token, :reset_password_token,
                      :last_login_attempt_at, :login_count, :failed_login_count]
  PUBLIC_ATTRS = (User.columns - NON_PUBLIC_ATTRS) rescue nil # test migration fails because table is not there

  def public_values
    values.slice *PUBLIC_ATTRS
  end

  def self.find(id, select = PUBLIC_ATTRS)
    where(id: id).select(*select).first
  end

  def self.signup(signup_hash)
    create(signup_hash)
  end

  def self.update_without_audit(id, attrs={})
    DB[:users].where(id: id).update(attrs)
  end

  def self.update_login_data(id, old_user, context)
    update_without_audit(id,  login_count: (old_user[:login_count] + 1), failed_login_count: 0, last_login_at: Time.now,
                              last_login_attempt_at: Time.now, last_login_ip: context.env['HTTP_X_FORWARDED_FOR'] || context.env['REMOTE_ADDR'])
  end

end

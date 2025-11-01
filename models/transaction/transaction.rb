class Transaction < Sequel::Model

  PER_PAGE = 25

  self.plugin :dirty

  many_to_one :user
  many_to_one :cashier
  many_to_one :account
  many_to_one :terminal
  many_to_one :operator, key: :operator_code
  many_to_one :voucher

  # parent/child for grouping
  many_to_one :parent, class: self
  one_to_many :children, key: :parent_id, class: self

  PUBLIC_ATTRS = [:id, :account_id, :cashier_id, :terminal_id, :type, :amount, :currency, :transaction_type, :status,
                  :description, :note, :balance, :systan, :reference_number, :services_batch_number,
                  :operator_code, :customer_number, :created_at]

  def public_values
    values.select{|k,v| PUBLIC_ATTRS.include?(k)}
  end

  # insert fee record
  def after_create
    insert_fee
    send_email
    super
  end

  def send_email
    return unless WALLET_TRANSACTION_TYPES.include?(self.transaction_type.to_sym)
    if user = self.user
      return unless user.settings['notifications'][self.transaction_type]
      Mailer.sendmail('/user/transaction', self, self.account, user)
    end
  end

  def insert_fee
    # no fee for fee
    return if FEES_TRANSACTION_TYPES.include?(transaction_type.to_sym)

    # no fee for credit # if its wallet to wallet transfer
    return if type == 'credit' # && transaction_type == 'transfer'

    # fee only for approves
    return if status != 'approved'

    DB.after_commit do
      # fee matcher
      status = 'approved'
      type = 'debit'
      account_type = account.type
      user_type = user.try(:type)

      # :account_type, :user_type, :transaction_type, :amount, :currency, :active
      if fee = Fee.where( status: status, type: type, account_type: account_type, user_type: user_type,
                          transaction_type: transaction_type, currency: currency, active: true).first


        # lock account
        account = Account.where(id: self.account_id).for_update.first
        new_account_balance = self.account.balance - fee.amount

        fee_transaction_type = self.transaction_type + '_fee'

        # insert record
        Transaction.create( account_id: self.account_id, user_id: self.user_id, terminal_id: self.terminal_id,
                            type: 'debit', status: 'approved', transaction_type: fee_transaction_type,
                            description: "Reference: ##{self.id}", balance: new_account_balance,
                            amount: fee.amount, currency: fee.currency, note: "Fee for #{ALL_TRANSACTION_TYPES[transaction_type.to_sym].downcase}")

        # update balance
        account.update(balance: Sequel.-(:balance, fee.amount))
      end

    end
  end

end

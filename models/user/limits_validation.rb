module LimitsValidation

  module SourceAccountLimitsValidation # dry-validation predicates
    def under_count_limit?(value)
      Validators::under_count_limit(source_account, user, transaction_type, source_global_limits, source_user_limits) # no source_account_debit_or_credit, its always debit
    end

    def under_volume_limit?(value)
      Validators::under_volume_limit(source_account, user, transaction_type, amount, source_global_limits, source_user_limits)
    end
  end

  module TargetAccountLimitsValidation # dry-validation predicates
    def target_account_under_count_limit?(value)
      Validators::under_count_limit(target_account, target_account_user, transaction_type, target_global_limits, target_user_limits, target_account_debit_or_credit)
    end

    def target_account_under_volume_limit?(value)
      Validators::under_volume_limit(target_account, target_account_user, transaction_type, amount, target_global_limits, target_user_limits, target_account_debit_or_credit)
    end
  end

  module Validators

    # check counts
    def self.under_count_limit(account, user, transaction_type, global_limits, user_limits, debit_or_credit = 'debit') # credit type is set for credit part of transfers or sale (target account)

      global_limits['count']&.each do |global_limit|

        # check for personal to override global limit
        personal_limit = self.select_personal_limit(global_limit, user_limits)
        limit = personal_limit ? personal_limit : global_limit

        period = 3600 * 24        if limit.period_type == 'day'
        period = 3600 * 24 * 7    if limit.period_type == 'week'
        period = 3600 * 24 * 30   if limit.period_type == 'month'

        no_of_trxs =  account.transactions_dataset.
                      where(status: 'approved', transaction_type: transaction_type, currency: account.currency).
                      where{created_at > Time.now - period}.count

        return false if no_of_trxs >= limit.amount
      end

      return true # its under limit if not returned earlier
    end

    # check volume
    def self.under_volume_limit(account, user, transaction_type, amount, global_limits, user_limits, debit_or_credit = 'debit')

      global_limits['volume']&.each do |global_limit|

        # check for personal to override global limit
        personal_limit = self.select_personal_limit(global_limit, user_limits)
        limit = personal_limit ? personal_limit : global_limit

        period = 3600 * 24        if limit.period_type == 'day'
        period = 3600 * 24 * 7    if limit.period_type == 'week'
        period = 3600 * 24 * 30   if limit.period_type == 'month'

        volume_of_trxs =  Transaction.dataset.where(account_id: account.id).
                          where(status: 'approved', transaction_type: transaction_type, currency: account.currency).
                          where{created_at > Time.now - period}.sum(:amount)

        return true   if !volume_of_trxs # volume_of_trxs is nil for count == 0 (sum returns  nil)
        return false  if volume_of_trxs + amount >= limit.amount
      end

      return true # its under limit if not returned earlier
    end

    def self.select_personal_limit(global_limit, user_limits)
      # {"count"=>[#<Limit1, Limit2 ... }>], "volume"=>[#<Limit1, Limit2 ... }>]}
      user_limits[global_limit.type]&.find{|user_limit| user_limit.period_type == global_limit.period_type && user_limit.period == global_limit.period}
    end

  end

end

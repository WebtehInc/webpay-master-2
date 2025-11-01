module CommonTerminalValidators
  def valid_terminal?(value)
    terminal&.active && account&.active
  end

  def valid_operator?(value)
    operator&.active
  end

  def valid_cashier?(value)
    cashier
  end

  def over_min_amount?(value)
    account && value > 0 && account.min_amount <= value
  end

  def below_max_amount?(value)
    account && account.max_amount >= value
  end

  def under_credit_limit?(value)
    account && account.credit_limit > account.exposure_amount + value
  end

  def working_time?(value)
    hours = Time.now.hour
    minutes = Time.now.min
    terminal &&
    hours >= terminal.opening_hours && minutes >= terminal.opening_minutes &&
    hours <= terminal.closing_hours && minutes <= terminal.closing_minutes
  end

  # ["credit", "debit"]
  # ["sft", "caribe", "vida", "mcb" ...]
  def valid_payment_method_type?(value)
    return true if value == "cash" and input.payment_method_type.blank?
    return true if value == "card" and MPOS_CARD_PAYMENT_METHOD_TYPES.reduce([]) { |a, i| a << i[:payment_method_type] }.stringify.include?(input.payment_method_type)
    return true if value == "check" and MPOS_CHECK_PAYMENT_METHOD_TYPES.reduce([]) { |a, i| a << i[:payment_method_type] }.stringify.include?(input.payment_method_type)
  end
end

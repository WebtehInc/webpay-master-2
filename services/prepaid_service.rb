require_relative 'prepaid/pagatinu'

module PrepaidService

  def self.fetch(operator_code, account_terminal_id, currency, pos_request)

    # map operator codes to their modules
    operators = {'pa' => PrepaidService::Pagatinu}

    # invalid service code
    return {error: {operator_code: ['unknown service']}} unless operators.keys.include?(operator_code)

    # call service
    operators[operator_code].fetch(operator_code, account_terminal_id, currency, pos_request)
  end
end

module CardAuthorization

  # wallet to switch types
  # NOTE: not currently enforced - card_data is pass through struct, still returned in config api
  TYPES_MAPPER = {
    card_authorization: :authorize,
    card_sale: :purchase,
    card_capture: :capture,
    card_refund: :refund,
    card_void: :void,
    card_adjustment: :adjustment,
    card_reversal: :technical_reversal
  }

  # authorization
  def self.authorize(terminal, params)
    process!(:authorize_or_purchase, terminal, params)
  end

  def self.sale(terminal, params)
    process!(:authorize_or_purchase, terminal, params)
  end

  def self.capture(terminal, params)
    process!(:authorize_or_purchase, terminal, params)
  end

  # capture, void, refund, adjustment
  def self.capture(terminal, params)
    process!(:transaction_management, terminal, params)
  end

  def self.void(terminal, params)
    process!(:transaction_management, terminal, params)
  end

  def self.refund(terminal, params)
    process!(:transaction_management, terminal, params)
  end

  def self.adjustment(terminal, params)
    process!(:transaction_management, terminal, params)
  end

  # reversal
  def self.reverse(terminal, params)
    process!(:technical_reversal, terminal, params)
  end

  def self.process!(type, terminal, params)
    # select gateway
    gateway = WebPay.opts[:iso_switch].new

    # static data from terminal record
    terminal_data = InfoSwitch.api_keys('Terminal', terminal.access_token)
    # terminal_data =  {authenticity_token: terminal.access_token, secret: terminal.terminal_key} # tid: terminal.tid, mid: terminal.mid

    # data stored in wallet transaction table - NOTE: we now validate card_data against input values
    # wallet_data = params.slice(:amount, :systan, :application_version).merge(currency: CURRENCY_CODES[params[:currency].to_s], transaction_type: TYPES_MAPPER[params[:transaction_type].to_sym].to_s)

    # switch input - merge wallet data and terminal data with everything coming from device (pristine data under :card_data key)
    request = params[:card_data].merge(terminal_data)#.merge(wallet_data)

    # acquirer response message
    # these keys are saved to wallet table: 'status', 'response_code', 'response_message', 'approval_code', 'reference_number'
    response = gateway.send(type, request)
  end
end

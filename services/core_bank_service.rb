module CoreBankService

  class << self
    attr_accessor :service
  end

  def self.balance bank_account
    # init service module - it is not available in module body, CoreBankService is incuded before WebPay definition
    self.service = FiservService if WebPay.opts[:core_bank_service] == 'fiserv'
    return resp = self.service.balance(bank_account)
  end

  def self.transfer type, source_account, target_account, amount, currency, opts = {}
    self.service = FiservService if WebPay.opts[:core_bank_service] == 'fiserv'
    return resp = self.service.transfer(type, source_account, target_account, amount, currency, opts)
  end

end
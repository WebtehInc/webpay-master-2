module ApiHelpers
  extend self

  def cache_response(input, response)
    MemoryStore.set("#{input.systan}/#{input.digest}", response, 5 * 60) # cache response 5 min
  end

  # ["cash", "card", "check" ...]
  PAYMENT_METHODS = MPOS_PAYMENT_METHODS_AND_TYPES.reduce([]) { |a, i| a << i[:payment_method] }.stringify

  # ["credit", "debit", "sft", "giro", "caribe" ...]
  PAYMENT_METHOD_TYPES = (MPOS_CARD_PAYMENT_METHOD_TYPES + MPOS_CHECK_PAYMENT_METHOD_TYPES).reduce([]) { |a, i| a << i[:payment_method_type] }.stringify
end

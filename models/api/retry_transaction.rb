class RetryTransaction
  def self.call(trx_processor, context)

    # input fix for TopUp card/manual entry
    if trx_processor == TopUp
      context.params[:card_pin] = false unless context.params[:card_pin]
      context.params[:card_number] = false unless context.params[:card_number]
      context.params[:account_number] = false unless context.params[:account_number]
    end

    input = trx_processor.new(context.params)
    cached_response = MemoryStore.get("#{input.systan}/#{input.digest}")
    cached_response ? context.render_success(cached_response) : trx_processor.call(context)
  end
end

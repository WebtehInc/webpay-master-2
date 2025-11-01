module TaxService
  extend self

  require "json"
  require "faraday"

  # env
  HOST_URL = ENV["TAX_HOST_URL"]
  API_KEY = ENV["TAX_API_KEY"]

  # cache
  PAYMENT_TTL = 10 * 60 # 10 minutes

  # paths
  CONFIRM_REFERENCE_PATH = "/api/tax/confirm-reference/request"
  PAYMENT_PATH = "/api/tax/payment/request"

  FARADAY = Faraday.new(:url => HOST_URL) do |builder|
    builder.adapter Faraday::Adapter::NetHttp
    builder.request :json
  end

  def confirm_reference_cache_key(platform_id)
    "tax-confirm-ref/#{platform_id}"
  end

  def confirm_reference(platform_id, request_time, payment_ref)
    http_response = FARADAY.post do |req|
      req.url CONFIRM_REFERENCE_PATH
      req.headers["X-Api-Key"] = API_KEY
      req.body = {
        "platformId": platform_id,
        "requestTime": request_time,
        "paymentRef": payment_ref,
      }.to_json
    end

    if http_response.status == 200
      confirm_reference = JSON.parse(http_response.body)
      ok = confirm_reference["responseDescription"] == "OK"

      if ok
        # cache response for next call
        confirm_reference_cache_key = confirm_reference_cache_key(platform_id)
        MemoryStore.set(confirm_reference_cache_key, confirm_reference, PAYMENT_TTL)

        { ok: ok, confirm_reference: confirm_reference }
      else
        { ok: ok, error: confirm_reference }
      end
    else
      { ok: false, error: { http_error: { body: http_response.body.to_s[0...100], status: http_response.status } } }
    end
  end

  def payment(platform_id, request_time, payment_amount)
    # load cache for previous call
    confirm_reference_cache_key = confirm_reference_cache_key(platform_id)
    confirm_reference = MemoryStore.get(confirm_reference_cache_key)
    raise("Tax platform_id not found or expired") if !confirm_reference

    http_response = FARADAY.post do |req|
      req.url PAYMENT_PATH
      req.headers["X-Api-Key"] = API_KEY
      req.body = {
        "platformId": platform_id,
        "requestTime": request_time,
        "paymentRef": confirm_reference["paymentRef"],
        "paymentAmount": payment_amount,
      }.to_json
    end

    if http_response.status == 200
      payment = JSON.parse(http_response.body)
      ok = payment["responseDescription"] == "OK"

      if ok
        { ok: ok, payment: payment, confirm_reference: confirm_reference }
      else
        { ok: ok, error: payment }
      end
    else
      { ok: false, error: { http_error: { body: http_response.body.to_s[0...100], status: http_response.status } } }
    end
  end
end

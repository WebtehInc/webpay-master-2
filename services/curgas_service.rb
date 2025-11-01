module CurgasService
  extend self

  require "json"
  require "faraday"

  # env
  HOST_URL = ENV["CG_HOST_URL"]
  USERNAME = ENV["CG_USERNAME"]
  PASSWORD = ENV["CG_PASSWORD"]

  # cache
  TOKEN_CACHE_KEY = "curgas-api-token"
  TOKEN_TTL = 10 * 60 * 60 # 10 hours
  ORDER_TTL = 10 * 60 # 10 minutes

  # errors
  ERRORS = {
    1 => "CurgasID does not exists",
    2 => "Order has already been placed",
    3 => "Order has exceeded maximum allowed number of cylinders",
    4 => "Previous order is already scheduled for delivery",
    5 => "Order failed, please contact Curgas",
  }

  # paths
  LOGIN_PATH = "/api/Auth/login"
  CHECK_ORDER_PATH = "/api/CurgasExternalOrders/:curgas_id/:quantity/:rush"
  NEW_ORDER_PATH = "/api/NewOrder"

  FARADAY = Faraday.new(:url => HOST_URL) do |builder|
    builder.adapter Faraday::Adapter::NetHttp
  end

  def login()
    http_response = FARADAY.post do |req|
      req.url LOGIN_PATH
      req.headers["Content-Type"] = "application/json"
      req.body = { "username": USERNAME,
                   "password": PASSWORD }.to_json
    end
    if http_response.status == 200
      { ok: true, token: http_response.body }
    else
      { ok: false, error: http_response.body, code: http_response.status }
    end
  end

  def get_token
    cached_token = MemoryStore.get(TOKEN_CACHE_KEY)
    return cached_token if cached_token

    token = login()[:token]
    raise("Could not get curgas api token") if !token
    puts "Caching curgas api token for #{TOKEN_TTL} seconds"
    MemoryStore.set(TOKEN_CACHE_KEY, token, TOKEN_TTL)
    token
  end

  def order_cache_key(cods_identity)
    "curgas-order-ref/#{cods_identity}"
  end

  def check_order_path(curgas_id, quantity, rush)
    CHECK_ORDER_PATH.gsub(/:curgas_id|:quantity|:rush/, ":curgas_id" => curgas_id, ":quantity" => quantity, ":rush" => rush)
  end

  def check_order(curgas_id, quantity, rush)
    http_response = FARADAY.get do |req|
      req.url check_order_path(curgas_id, quantity, rush)
      req.headers["Authorization"] = "Bearer #{get_token}"
    end
    if http_response.status == 200
      check_order = JSON.parse(http_response.body)[0]
      ok = check_order["error"] == 0
      if ok and check_order["can_order"] == "Y"
        # cache response for second call
        check_order_key = order_cache_key(check_order["cods_identity"])
        MemoryStore.set(check_order_key, check_order, ORDER_TTL)
      else
        # add descriptive error message
        check_order["error_message"] = ERRORS[check_order["error"]]
      end
      { ok: ok, check_order: check_order, error: { check_order: check_order["error_message"] } }
    else
      { ok: false, error: { http_error: { body: http_response.body.to_s[0...100], status: http_response.status } } }
    end
  end

  def new_order(cods_identity)
    check_order = MemoryStore.get(order_cache_key(cods_identity))
    raise("Curgas cods_identity not found or expired") if !check_order
    http_response = FARADAY.post do |req|
      req.url NEW_ORDER_PATH
      req.headers["Content-Type"] = "application/json"
      req.headers["Authorization"] = "Bearer #{get_token}"
      req.body = {
        "company": "01",
        "curgas_id": check_order["curgas_id"],
        "cods_identity": cods_identity,
        "quantity_request": check_order["quantity_request"],
        "rush_delivery": check_order["rush_delivery"],
        "total_paid": check_order["total_order"],
      }.to_json
    end
    if http_response.status == 200
      new_order = JSON.parse(http_response.body)[0]
      ok = new_order["error"] == 0
      new_order["error_message"] = ERRORS[new_order["error"]] if !ok
      { ok: ok, new_order: new_order, error: { new_order: new_order["error_message"] } }
    else
      { ok: false, error: { http_error: { body: http_response.body.to_s[0...100], status: http_response.status } } }
    end
  end
end

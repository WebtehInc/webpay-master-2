module PagatinuService
  extend self

  require "json"
  require "faraday"

  # env
  HOST_URL = ENV["PG_HOST_URL"]
  USERNAME = ENV["PG_USERNAME"]
  PASSWORD = ENV["PG_PASSWORD"]
  PAYMENT_PROVIDER = ENV["PG_PAYMENT_PROVIDER"]
  RECHARGE_PATH = ENV["PG_RECHARGE_PATH"]

  FARADAY = Faraday.new(:url => HOST_URL) do |builder|
    builder.adapter Faraday::Adapter::NetHttp
    builder.use Faraday::Request::BasicAuthentication, USERNAME, PASSWORD
  end

  def recharge(customer_id, tx_id, amount, validate_only)
    # optional_params = {"UseCase" => "New", "TicketInfo" => "Custom text"}
    default_params = { "ChannelId" => "External" }
    params = default_params.merge(
      "CustomerId" => customer_id,
      "ValidateOnly" => validate_only,
      "PaymentTransID" => tx_id,
      "Amount" => amount,
      "PaymentProvider" => PAYMENT_PROVIDER,
    )
    http_response = FARADAY.get do |req|
      req.url RECHARGE_PATH, params
      req.headers["Content-Type"] = "application/json"
      req.headers["Accept"] = "application/json"
    end
    if http_response.status == 200
      response = JSON.parse(http_response.body)

      response_map = {
        "Account" => nil,
        "Delta" => nil,
        "PaymentTransID" => nil,
        "OwnTransID" => nil,
        "Contract.Address" => nil,

        "ErrorCode" => nil,
        "ErrorText" => nil,
        "ErrorType" => nil,
      }

      # extract values
      response["param"].each do |param|
        key = param["pname"]
        if response_map.has_key?(key)
          response_map[key] = param["pval"]
        end
      end

      # remove empty values
      response_map = response_map.select { |k, v| !v.nil? }

      # success flag
      ok = !response_map.has_key?("ErrorCode")

      # buld result map
      result = { ok: ok }.merge(recharge: response_map)

      # add an error field
      result.merge!(error: { recharge: "#{response_map["ErrorText"]} (#{response_map["ErrorCode"]})" }) unless ok

      # return result
      result
    else
      { ok: false, error: { http_error: { body: http_response.body.to_s[0...100], status: http_response.status } } }
    end
  end
end

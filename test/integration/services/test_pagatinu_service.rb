require_relative "../integration_helper"

require "webmock"
include WebMock::API

class PagatinuServiceTest < Test
  def setup
    super
    VCR.eject_cassette
    VCR.turn_off!
    WebMock.enable!
    @customer_id = "customer-id"
    @tx_id = "123-abc-456"
    @amount = 1000
    @validate_only = false
  end

  def test_recharge

    ### with ValidateOnly = false
    body_mock_when_ok = {
      "name": "recharge",
      "param": [
        {
          "pname": "Account",
          "pval": "191000",
        },
        {
          "pname": "Delta",
          "pval": @amount,
        },
        {
          "pname": "PaymentTransID",
          "pval": @tx_id,
        },
        {
          "pname": "OwnTransID",
          "pval": "G20000000307",
        },
        {
          "pname": "Contract.Address",
          "pval": "Some address",
        },
      ],
    }

    # mock
    url = PagatinuService::HOST_URL + PagatinuService::RECHARGE_PATH
    url = "#{url}?CustomerId=#{@customer_id}&PaymentTransID=#{@tx_id}&Amount=#{@amount}&ChannelId=External&PaymentProvider=Pagafasil&ValidateOnly=#{@validate_only}"
    stub_request(:any, /recharge/).to_return(status: 200, body: body_mock_when_ok.to_json, headers: {})

    # call
    result = PagatinuService.recharge(@customer_id, @tx_id, @amount, true)

    # verify when ok
    assert_equal result, { :ok => true,
                           recharge: { "Account" => "191000", "Delta" => @amount, "PaymentTransID" => @tx_id, "OwnTransID" => "G20000000307", "Contract.Address" => "Some address" } }

    body_mock_when_error = {
      "name": "recharge",
      "param": [
        {
          "pname": "ErrorCode",
          "pval": "1006",
        },
        {
          "pname": "ErrorText",
          "pval": "PaymentTransID already used",
        },
        {
          "pname": "ErrorType",
          "pval": "Recharge",
        },
      ],
    }

    # mock
    stub_request(:get, url).to_return(status: 200, body: body_mock_when_error.to_json, headers: {})

    # call
    result = PagatinuService.recharge(@customer_id, @tx_id, @amount, @validate_only)

    # verify when error
    assert_equal result, { :ok => false,
                           recharge: { "ErrorCode" => "1006", "ErrorText" => "PaymentTransID already used", "ErrorType" => "Recharge" },
                           error: { recharge: "PaymentTransID already used (1006)" } }

    ### with ValidateOnly = true
    @validate_only = true
    body_mock_when_ok = {
      "name": "recharge",
      "param": [
        {
          "pname": "Account",
          "pval": "191000",
        },
        {
          "pname": "PaymentTransID",
          "pval": @tx_id,
        },
        {
          "pname": "Contract.Address",
          "pval": "Some address",
        },
      ],
    }

    # mock
    url = PagatinuService::HOST_URL + PagatinuService::RECHARGE_PATH
    url = "#{url}?CustomerId=#{@customer_id}&PaymentTransID=#{@tx_id}&Amount=#{@amount}&ChannelId=External&PaymentProvider=Pagafasil&ValidateOnly=#{@validate_only}"
    stub_request(:any, /recharge/).to_return(status: 200, body: body_mock_when_ok.to_json, headers: {})

    # call
    result = PagatinuService.recharge(@customer_id, @tx_id, @amount, true)

    # verify when ok
    assert_equal result, { :ok => true,
                           recharge: { "Account" => "191000", "PaymentTransID" => @tx_id, "Contract.Address" => "Some address" } }
  end
end

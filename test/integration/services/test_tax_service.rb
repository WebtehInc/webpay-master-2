require_relative "../integration_helper"

require "webmock"
include WebMock::API

class TaxServiceTest < Test
  def setup
    super
    VCR.eject_cassette
    VCR.turn_off!
    WebMock.enable!
  end

  def test_flow
    platform_id = "37281025-32da-48fb-bbac-abaeb6be0e88" # SecureRandom.uuid()
    request_time = "2025-03-09 15:53:46 -0400" # Time.now.to_s
    payment_ref = "31201810010471"
    payment_amount = "1000"

    MemoryStore.delete(TaxService.confirm_reference_cache_key(platform_id))

    ### test confirm_reference
    confirm_reference_mock = {
      "responseTime" => "2025-03-09 15:00:23",
      "platformId" => platform_id,
      "referenceId" => "3D8CB4C0-18FD-EF11-B879-549F350A9EA9",
      "customerName" => "XTPUTCP YXKGI VICRFETLEZ",
      "paymentType" => "Assessment/Aanslag",
      "paymentRef" => payment_ref,
      "responseDescription" => "OK",
      "customerId" => "171476748",
      "responseValue" => "200",
      "paymentPeriod" => "2018-13",
      "taxType" => "AFS",
    }

    url = TaxService::HOST_URL + TaxService::CONFIRM_REFERENCE_PATH
    headers = { "X-Api-Key" => TaxService::API_KEY, "Content-Type" => "application/json" }
    stub_request(:post, url).with(headers: headers).to_return(status: 200, body: confirm_reference_mock.to_json, headers: {})

    # call
    result = TaxService.confirm_reference(platform_id, request_time, payment_ref)

    # verify result
    assert_equal result, { :ok => true, :confirm_reference => confirm_reference_mock }

    # verify cache
    cached_confirm_reference = MemoryStore.get(TaxService.confirm_reference_cache_key(platform_id))
    assert_equal cached_confirm_reference, confirm_reference_mock

    ### test payment
    payment_mock = {
      "responseDescription" => "OK",
      "paymentId" => "8E6330D9-18FD-EF11-B879-549F350A9EA9",
      "responseTime" => "2025-03-09 15:01:04.667",
      "responseValue" => "200",
      "platformId" => platform_id,
      "paymentAmount" => payment_amount,
      "paymentRef" => payment_ref,
    }

    url = TaxService::HOST_URL + TaxService::PAYMENT_PATH
    headers = { "X-Api-Key" => TaxService::API_KEY, "Content-Type" => "application/json" }
    stub_request(:post, url).with(headers: headers).to_return(status: 200, body: payment_mock.to_json, headers: {})

    # call
    result = TaxService.payment(platform_id, request_time, payment_amount)

    # verify
    confirm_reference_cache_key = TaxService.confirm_reference_cache_key(platform_id)
    confirm_reference = MemoryStore.get(confirm_reference_cache_key)
    assert_equal result, { :ok => true, :payment => payment_mock, confirm_reference: confirm_reference }

    ## failure

    # call fails when platform_id not found or expired
    assert_raises RuntimeError do
      TaxService.payment("unknown", request_time, payment_amount)
    end

    # call fails when responseDescription != OK
    payment_mock = {
      "errorDescription" => "No valid Confirmation found",
      "responseDescription" => "Bad Request",
      "paymentId" => "8ADBA441-17FD-EF11-B879-549F350A9EA9",
      "responseTime" => "2025-03-09 14:49:40.907",
      "errorCode" => 801,
      "responseValue" => "400",
      "platformId" => "3306290C-15E6-4757-BE89-A37A4B5FB34b",
    }

    stub_request(:post, url).with(headers: headers).to_return(status: 200, body: payment_mock.to_json, headers: {})

    # call
    result = TaxService.payment(platform_id, request_time, payment_amount)

    # verify
    assert_equal result, { :ok => false, :error => payment_mock }
  end
end

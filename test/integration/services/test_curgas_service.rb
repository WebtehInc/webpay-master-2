require_relative "../integration_helper"

require "webmock"
include WebMock::API

class CurgasServiceTest < Test
  def setup
    super
    VCR.eject_cassette
    VCR.turn_off!
    WebMock.enable!
    @token_mock = "token"
    @curgas_id = "123"
    @cods_identity = "456"
    @amount = 1000
  end

  def test_flow
    MemoryStore.delete(CurgasService::TOKEN_CACHE_KEY)
    MemoryStore.delete(CurgasService.order_cache_key(@cods_identity))

    ### test login
    url = CurgasService::HOST_URL + CurgasService::LOGIN_PATH
    payload = { "username": CurgasService::USERNAME, "password": CurgasService::PASSWORD }.to_json
    body_mock = @token_mock

    # ok
    stub_request(:post, url).with(body: payload).to_return(status: 200, body: body_mock, headers: {})

    # call
    result = CurgasService.login()

    # verify
    assert_equal result, { :ok => true, :token => @token_mock }
    assert_equal CurgasService.get_token, @token_mock # cache

    # failed
    body = "User not found."
    stub_request(:post, url).with(body: payload).to_return(status: 400, body: body, headers: {})

    # call
    result = CurgasService.login()

    # verify
    assert_equal result, { :ok => false, :error => body, :code => 400 }

    ### test check_order
    body_mock = [
      {
        "curgas_id" => @curgas_id,
        "quantity_request" => 1,
        "rush_delivery" => 1,
        "can_order" => "Y",
        "total_order" => @amount,
        "cods_identity" => @cods_identity,
        "error" => 0,
      },
    ]
    quantity = rush = 1
    url = CurgasService::HOST_URL + CurgasService.check_order_path(@curgas_id, quantity, rush)
    stub_request(:get, url).with(headers: { "Authorization" => "Bearer #{@token_mock}" }).to_return(status: 200, body: body_mock.to_json, headers: {})

    # call
    result = CurgasService.check_order(@curgas_id, quantity, rush)

    # verify result
    assert_equal result, { :ok => true, :check_order => body_mock[0], :error => { :check_order => nil } }

    # verify cache
    cached_check_order = MemoryStore.get(CurgasService.order_cache_key(@cods_identity))
    assert_equal cached_check_order["cods_identity"], @cods_identity

    ### test new_order
    payload = {
      "company" => "01",
      "curgas_id" => @curgas_id,
      "cods_identity" => @cods_identity,
      "quantity_request" => 1,
      "rush_delivery" => 1,
      "total_paid" => @amount,
    }.to_json

    body_mock = [
      {
        "company" => "01",
        "curgas_id" => @curgas_id,
        "cods_identity" => @cods_identity,
        "quantity_request" => 1,
        "rush_delivery" => 1,
        "total_paid" => @amount,
        "order_num" => "123",
        "error" => 0,
      },
    ]
    url = CurgasService::HOST_URL + CurgasService::NEW_ORDER_PATH
    stub_request(:post, url).with(body: payload, headers: { "Authorization" => "Bearer #{@token_mock}" }).to_return(status: 200, body: body_mock.to_json, headers: {})

    # call
    result = CurgasService.new_order(@cods_identity)

    # verify
    assert_equal result, { :ok => true, :new_order => body_mock[0], :error => { :new_order => nil } }
  end
end

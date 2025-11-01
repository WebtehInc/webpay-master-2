require_relative "../integration_helper"
require_relative "../../fixtures/pagatinu_rest"

require "webmock"
include WebMock::API

class PagatinuRestServiceTest < Test
  DATETIME_FORMAT = "%Y%m%d%H%M%S"

  def setup
    super
    VCR.eject_cassette
    VCR.turn_off!
    WebMock.enable!
    @ms_no = "123456"
    @stan = "123456789"
    @purchase_value = 1000
    @date_time = Time.now.strftime(DATETIME_FORMAT)
    @pagatinu_payload = { "terminalID" => "0000000000002", "msNo" => @ms_no, "stan" => @stan, "dateTime" => @date_time, "purchaseValue" => @purchase_value / 100.0, "operatorName" => "pagafasil", "password" => "pagafasil" }.to_json
  end

  def test_credit
    url = PagatinuRestService::HOST_URL + PagatinuRestService::CREDIT_PATH
    stub_request(:post, url).with(body: @pagatinu_payload, headers: { "X-Api-Key" => PagatinuRestService::API_KEY }).to_return(status: 200, body: VALID_BODY_MOCK.to_json, headers: {})

    # call
    result = PagatinuRestService.credit(@purchase_value, @stan, @ms_no, @date_time)

    # verify
    assert_equal result, { :ok => true, :credit => {
                   :customer_name => "AGHA LIMITED",
                   :datetime => "2024-05-13T08:20:47.1317707-04:00",
                   :terminal_id => "0000000000002",
                   :meter_number => "04257670895",
                   :receipt_number => "10071872",
                   :account_number => "3101149376",
                   :tariff => "DOMESTIC ELECTRICITY",
                   :energy_value => "132.7",
                   :energy2_value => nil,
                   :energy3_value => nil,
                   :energy_si_unit => "kWh",
                   :energy2_si_unit => nil,
                   :energy3_si_unit => nil,
                   :amount_paid_currency => "ANG",
                   :amount_paid_value => "100",
                   :token1 => "04257670895000001327",
                   :token2 => nil,
                   :token3 => nil,
                   :customer_number => "04257670895",
                   :transaction_id => "1230000001",
                 } }
  end

  def test_credit_client_error
    body_mock = {
      "response" => {
        "soapFault" => {
          "faultcode" => "soap:Client",
          "faultstring" => "System.Web.Services.Protocols.SoapException: Server was unable to read request. ---> System.InvalidOperationException: There is an error in XML document (20, 30). ---> System.FormatException: Input string was not in a correct format.\n   at System.Number.StringToNumber(String str, NumberStyles options, NumberBuffer& number, NumberFormatInfo info, Boolean parseDecimal)\n   at System.Number.ParseDecimal(String value, NumberStyles options, NumberFormatInfo numfmt)\n   at Microsoft.Xml.Serialization.GeneratedAssembly.XmlSerializationReader1.Read2_Currency(Boolean isNullable, Boolean checkType)\n   at Microsoft.Xml.Serialization.GeneratedAssembly.XmlSerializationReader1.Read88_PurchaseValueCurrency(Boolean isNullable, Boolean checkType)\n   at Microsoft.Xml.Serialization.GeneratedAssembly.XmlSerializationReader1.Read90_PurchaseValue(Boolean isNullable, Boolean checkType)\n   at Microsoft.Xml.Serialization.GeneratedAssembly.XmlSerializationReader1.Read101_TrialCreditVendReq(Boolean isNullable, Boolean checkType)\n   at Microsoft.Xml.Serialization.GeneratedAssembly.XmlSerializationReader1.Read394_TrialCreditVendRequest()\n   at System.Xml.Serialization.XmlSerializer.Deserialize(XmlReader xmlReader, String encodingStyle, XmlDeserializationEvents events)\n   --- End of inner exception stack trace ---\n   at System.Xml.Serialization.XmlSerializer.Deserialize(XmlReader xmlReader, String encodingStyle, XmlDeserializationEvents events)\n   at System.Web.Services.Protocols.SoapServerProtocol.ReadParameters()\n   --- End of inner exception stack trace ---\n   at System.Web.Services.Protocols.SoapServerProtocol.ReadParameters()\n   at System.Web.Services.Protocols.WebServiceHandler.CoreProcessRequest()",
          "detail" => {},
        },
      },
    }

    url = PagatinuRestService::HOST_URL + PagatinuRestService::CREDIT_PATH
    stub_request(:post, url).with(body: @pagatinu_payload, headers: { "X-Api-Key" => PagatinuRestService::API_KEY }).to_return(status: 200, body: body_mock.to_json, headers: {})

    # call
    result = PagatinuRestService.credit(@purchase_value, @stan, @ms_no, @date_time)

    # verify
    assert_equal result, { :ok => false, :error => body_mock["response"]["soapFault"] }
  end

  def test_credit_server_error
    body_mock = {
      "response" => {
        "soapFault" => {
          "faultcode" => "soap:Server",
          "faultstring" => "System.Web.Services.Protocols.SoapException: Soap Exception From Server\n   at Conlog.PowerHub.Gateway.Web.Api.XMLVendService.CreditVendRequest(CreditVendReq request) in D:\\a\\1\\s\\src\\Gateway.Web.Api\\GatewayServiceASP.asmx.cs:line 398",
          "faultactor" => "url",
          "detail" => {
            "XMLVendFaultResp" => {
              "clientID" => {
                "@attributes" => {
                  "ean" => "VUPSB",
                },
              },
              "serverID" => {
                "@attributes" => {
                  "id" => "1",
                },
              },
              "terminalID" => {
                "@attributes" => {
                  "ean" => "0000000000002",
                },
              },
              "reqMsgID" => {
                "@attributes" => {
                  "dateTime" => "20240403123920",
                  "uniqueNumber" => "11112",
                },
              },
              "respDateTime" => "2024-05-13T09:50:56.2134178-04:00",
              "dispHeader" => "Vending Server Cluster Error",
              "operatorMsg" => "There was a fault at the server processing the request",
              "fault" => {
                "desc" => "Transaction has been terminated due to duplicate unique value.",
              },
            },
          },
        },
      },
    }

    url = PagatinuRestService::HOST_URL + PagatinuRestService::CREDIT_PATH
    stub_request(:post, url).with(body: @pagatinu_payload, headers: { "X-Api-Key" => PagatinuRestService::API_KEY }).to_return(status: 200, body: body_mock.to_json, headers: {})

    # call
    result = PagatinuRestService.credit(@purchase_value, @stan, @ms_no, @date_time)

    # verify
    assert_equal result, { :ok => false, :error => body_mock["response"]["soapFault"] }
  end

  def test_credit_http_error
    body_mock = "some http body with error"

    url = PagatinuRestService::HOST_URL + PagatinuRestService::CREDIT_PATH
    stub_request(:post, url).with(body: @pagatinu_payload, headers: { "X-Api-Key" => PagatinuRestService::API_KEY }).to_return(status: 400, body: body_mock, headers: {})

    # call
    result = PagatinuRestService.credit(@purchase_value, @stan, @ms_no, @date_time)

    # verify
    assert_equal result, { :ok => false, :error => { http_error: { body: body_mock, status: 400 } } }
  end
end

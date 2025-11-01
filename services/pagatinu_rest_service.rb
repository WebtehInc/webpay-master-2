module PagatinuRestService
  extend self

  require "json"
  require "faraday"

  # env
  HOST_URL = ENV["PG_REST_HOST_URL"]
  TERMINAL_ID = ENV["PG_REST_TERMINAL_ID"]
  OPERATOR_NAME = ENV["PG_REST_OPERATOR_NAME"]
  PASSWORD = ENV["PG_REST_PASSWORD"]
  API_KEY = ENV["PG_REST_API_KEY"]

  # paths
  CREDIT_PATH = "/api/vendor/credit"
  TRIAL_PATH = "/api/vendor/credit/trial"
  # LAST_ADVICE_PATH = "/api/advice/last"

  FARADAY = Faraday.new(:url => HOST_URL) do |builder|
    builder.adapter Faraday::Adapter::NetHttp
  end

  def first_value_from_txs(txs, *attrs)
    txs.map.each { |tx| tx.dig(*attrs) }.compact.first
  end

  def credit(purchase_value, stan, ms_no, date_time)
    http_response = FARADAY.post do |req|
      req.url CREDIT_PATH
      req.headers["Content-Type"] = "application/json"
      req.headers["X-Api-Key"] = API_KEY
      req.body = {

        "terminalID": TERMINAL_ID,
        "msNo": ms_no,
        "stan": stan,
        "dateTime": date_time,
        "purchaseValue": purchase_value / 100.0,
        "operatorName": OPERATOR_NAME,
        "password": PASSWORD,

      }.to_json
    end
    if http_response.status == 200
      parsed_response = JSON.parse(http_response.body)

      ok = !!parsed_response.dig("response", "creditVendResp")

      if ok
        credit = parsed_response["response"]["creditVendResp"]
        txs = credit.dig("creditVendReceipt", "transactions", "tx")

        { ok: ok, credit: {
          # 1. Customer Name: creditVendResp->custVendDetail->@attributes->name
          customer_name: credit.dig("custVendDetail", "@attributes", "name"),

          # 2. Date And Time: creditVendResp->respDateTime
          datetime: credit.dig("respDateTime"),

          # 3. Terminal ID: creditVendResp->terminalID->@attributes->ean
          terminal_id: credit.dig("terminalID", "@attributes", "ean"),

          # 4. Meter Number: creditVendResp->creditVendReceipt->transactions->tx->creditTokenIssue->q1meterDetail->@attributes->msno
          meter_number: first_value_from_txs(txs, "creditTokenIssue", "q1meterDetail", "@attributes", "msno"),

          # 5. Receipt Number: creditVendResp->creditVendReceipt->@attributes->receiptNo
          receipt_number: credit.dig("creditVendReceipt", "@attributes", "receiptNo"),

          # 6. Account Number: creditVendResp->custVendDetail->@attributes->accNo
          account_number: credit.dig("custVendDetail", "@attributes", "accNo"),

          # 7. Tariff: creditVendResp->custVendDetail->@attributes->name
          # tariff: txs.dig("tariff", "name"),
          tariff: first_value_from_txs(txs, "tariff", "name"),

          # 8. Cost: creditVendResp->creditVendReceipt->transactions->tenderAmt->@attributes->symbol + creditVendResp->creditVendReceipt->transactions->tenderAmt->@attributes->value
          # NOTE: same as 8
          # cost_currency: credit.dig("creditVendReceipt", "transactions", "tenderAmt", "@attributes", "symbol"),
          # cost_value: credit.dig("creditVendReceipt", "transactions", "tenderAmt", "@attributes", "value"),

          # 9. Energy: creditVendResp->creditVendReceipt->transactions->tx[n]->creditTokenIssue->q1units->@attributes->value + creditVendResp->creditVendReceipt->transactions->tx[n]->creditTokenIssue->q1units->@attributes->siUnit
          # Note: There may be more that on token generated, in that case iterate through creditVendResp->creditVendReceipt->transactions->tx[n]
          # energy: energy_value.each_with_index.map { |value, index| { value: value, si_unit: energy_si_unit[index] } },
          energy_si_unit: first_value_from_txs(txs, "creditTokenIssue", "q1units", "@attributes", "siUnit"),
          energy2_si_unit: first_value_from_txs(txs, "creditTokenIssue", "q2units", "@attributes", "siUnit"),
          energy3_si_unit: first_value_from_txs(txs, "creditTokenIssue", "q3units", "@attributes", "siUnit"),
          energy_value: first_value_from_txs(txs, "creditTokenIssue", "q1units", "@attributes", "value"),
          energy2_value: first_value_from_txs(txs, "creditTokenIssue", "q2units", "@attributes", "value"),
          energy3_value: first_value_from_txs(txs, "creditTokenIssue", "q3units", "@attributes", "value"),

          # 10. Amount Paid: creditVendResp->creditVendReceipt->transactions->tenderAmt->@attributes->symbol + creditVendResp->creditVendReceipt->transactions->tenderAmt->@attributes->value
          amount_paid_currency: credit.dig("creditVendReceipt", "transactions", "tenderAmt", "@attributes", "symbol"),
          amount_paid_value: credit.dig("creditVendReceipt", "transactions", "tenderAmt", "@attributes", "value"),

          # 11. Amount Breakdown: creditVendResp->creditVendReceipt->transactions->tariffBreakdown->{{iterate through all steps}}
          # amount_breakdown: txs.dig("tariffBreakdown"),

          # 12. Pins/Tokens: creditVendResp->creditVendReceipt->transactions->tx{{ iterate through }}->creditTokenIssue->{{ index }} + token->{{ index }} + stsCipher
          token1: first_value_from_txs(txs, "creditTokenIssue", "q1token", "q1stsCipher"),
          token2: first_value_from_txs(txs, "creditTokenIssue", "q2token", "q2stsCipher"),
          token3: first_value_from_txs(txs, "creditTokenIssue", "q3token", "q3stsCipher"),

          # 13. Customer Number: creditVendResp->creditVendReceipt->transactions- >tx->creditTokenIssue->q1meterDetail->@attributes->msno
          customer_number: first_value_from_txs(txs, "creditTokenIssue", "q1meterDetail", "@attributes", "msno"),

          # NOTE: internal WP fileds
          # 14. Payment Mode: Please use the payment mode selected in the terminal.
          # 15. Cashier Name: Please use logged on cashier name

          # 16. Transaction ID: creditVendResp->reqMsgID->@attributes->uniqueNumber
          transaction_id: credit.dig("reqMsgID", "@attributes", "uniqueNumber"),

        } }
      else
        error = parsed_response["response"]["soapFault"]
        puts "PAGATINU ERROR: #{error}"
        { ok: ok, error: error }
      end
    else
      puts "PAGATINU HTTP ERROR: [#{http_response.status}] #{http_response.body.to_s}"
      { ok: false, error: { http_error: { body: http_response.body.to_s[0...100], status: http_response.status } } }
    end
  end

  def trial(amount, stan, ms_no, date_time)
    http_response = FARADAY.post do |req|
      req.url TRIAL_PATH
      req.headers["Content-Type"] = "application/json"
      req.headers["X-Api-Key"] = API_KEY
      req.body = {

        "terminalID": TERMINAL_ID,
        "msNo": ms_no,
        "stan": stan,
        "dateTime": date_time,
        "amount": amount / 100.0,
        "operatorName": OPERATOR_NAME,
        "password": PASSWORD,

      }.to_json
    end

    if http_response.status == 200
      parsed_response = JSON.parse(http_response.body)
      { ok: true, trial: parsed_response }
    else
      puts "PAGATINU HTTP ERROR: [#{http_response.status}] #{http_response.body.to_s}"
      { ok: false, error: { http_error: { body: http_response.body.to_s[0...100], status: http_response.status } } }
    end
  end
end

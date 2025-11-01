require_relative "../integration_helper"

class TestLimitsForSaleWallet < Test

  def test_limits_for_sale_wallet

    # merchant setup
    merchant = signup_user(email: 'merchant@email.com')
    account  = generate_business_account merchant
    terminal = generate_terminal account_id: account.id
    time = Time.now
    terminal.update(opening_hours: time.hour - 1, opening_minutes: time.min - 1, closing_hours: time.hour + 1, closing_minutes: time.min + 1) # open store
    login_user(email: 'merchant@email.com')
    cashier, cashier_pin = create_cashier terminal

    # user setup
    user = signup_user(email: 'user@email.com')
    wallet_account = user.accounts.first
    card_pin = '1234'
    card = generate_card user, pin_block: card_pin
    card_number = card.pan

    # trx setup
    systan = '00001234'
    currency = wallet_account.currency

    amount = 100
    wallet_account.update balance: 10 * amount

    # import limit fixtures
    Limit.instance_eval {serializer file_path: './test/fixtures', file_name: "limits.json"}
    Limit.send(:save_to_db_from_file!, true)

    # do 3 sales; limit is 3 in fixtures
    sale_wallet(terminal, card_number, card_pin, amount/10, currency, systan, cashier_pin, cashier)
    sale_wallet(terminal, card_number, card_pin, amount/10, currency, systan, cashier_pin, cashier)
    sale_wallet(terminal, card_number, card_pin, amount/10, currency, systan, cashier_pin, cashier)

    # limit now by count
    decline_sale_wallet(terminal, card_number, card_pin, amount, currency, systan, cashier_pin, cashier, LIMIT_COUNT_MSG_FOR_TARGET_ACCOUNT)

    # reset counts
    Transaction.dataset.delete

    # do 2 sales; limit is 210 in fixtures
    sale_wallet(terminal, card_number, card_pin, amount, currency, systan, cashier_pin, cashier)
    sale_wallet(terminal, card_number, card_pin, amount, currency, systan, cashier_pin, cashier)

    # limit now by volume
    decline_sale_wallet(terminal, card_number, card_pin, 10, currency, systan, cashier_pin, cashier, LIMIT_VOLUME_MSG_FOR_TARGET_ACCOUNT)

  end

  # helpers for approve/decline
  def sale_wallet(terminal, card_number, card_pin, amount, currency, systan, cashier_pin, cashier)
    digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + card_number + amount.to_s + currency + systan)
    post '/api/sale-wallet', {  amount: amount, currency: currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.', card_number: card_number, card_pin: card_pin,
                                client_datetime: Time.now.to_s, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.ok?
  end

  def decline_sale_wallet(terminal, card_number, card_pin, amount, currency, systan, cashier_pin, cashier, resp_msg)
    digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + card_number + amount.to_s + currency + systan)
    post '/api/sale-wallet', {  amount: amount, currency: currency, access_token: terminal.access_token, digest: digest,
                                systan: systan, api_version: '1.0.0.', application_version: '1.0.0.', card_number: card_number, card_pin: card_pin,
                                client_datetime: Time.now.to_s, cashier_pin: cashier_pin, cashier_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal resp_msg, JSON.parse(last_response.body)['amount'][0]
  end

end

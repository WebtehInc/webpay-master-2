require_relative "../integration_helper"

class TestGenerateCSK < Test

  def test_generate_CSK

    m = InfoSwitch::Mocks.new
    user = signup_user
    account  = generate_business_account user
    terminal = generate_terminal account_id: account.id,
      infoswitch_enabled: true, access_token: 'uber1234', generate_session_keys: true
    card = generate_card user,
      infoswitch_enabled: true, access_token: 'uber1234'

    # create cashier
    login_user
    cashier, cashier_pin = create_cashier terminal

    card_serial = card.serial_number
    card_challenge = m.mifare_session_key_exchange[:card_challenge]

    digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + card_serial + card_challenge)

    # no payload
    post '/api/generate-csk', {}.to_json
    assert last_response.unprocessable?
    assert_equal 6, JSON.parse(last_response.body).keys.size

    # invalid access_token
    post '/api/generate-csk', { access_token: 'any', digest: 'any',
                                api_version: '1.0.0.', application_version: '1.0.0.',
                                card_serial: card_serial, card_challenge: card_challenge}.to_json
    assert last_response.unprocessable?
    assert_equal 'unknown or disabled terminal', JSON.parse(last_response.body)['access_token'][0]

    # invalid digest
    post '/api/generate-csk', { access_token: terminal.access_token, digest: 'any',
                                api_version: '1.0.0.', application_version: '1.0.0.',
                                card_serial: card_serial, card_challenge: card_challenge}.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['digest'][0]

    # funny card challenge
    card_challenge = 'lolol'
    digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + card_serial + card_challenge)
    post '/api/generate-csk', { access_token: terminal.access_token, digest: digest,
      api_version: '1.0.0.', application_version: '1.0.0.',
      card_serial: card_serial, card_challenge: card_challenge}.to_json
    refute last_response.ok?
    resp = JSON.parse(last_response.body)
    assert resp['crypto_error']

    # resp OK
    card_challenge = m.mifare_session_key_exchange[:card_challenge]
    digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + card_serial + card_challenge)
    post '/api/generate-csk', { access_token: terminal.access_token, digest: digest,
                                api_version: '1.0.0.', application_version: '1.0.0.',
                                card_serial: card_serial, card_challenge: card_challenge}.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)

    # check response fields
    assert_equal 6, resp.keys.size

    # check returned values
    assert resp['ccr'].length > 40
    assert resp['csk'].length > 20
    assert_equal 6, resp['kcv'].length

    # check returned digest
    resp_digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + resp['ccr'] + resp['csk'] + resp['kcv'])
    assert_equal resp_digest, resp['digest']
  end

end

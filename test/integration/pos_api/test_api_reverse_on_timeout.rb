require_relative "../integration_helper"

class TestApiReverseOnTimeout < Test

  def test_api_reverse_on_timeout
    systan    = 123
    amount    = 12345
    type      = 'top-up'
    account   = generate_business_account signup_user
    terminal  = generate_terminal account_id: account.id
    digest    = Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, systan, type)

    # no payload
    post '/api/reverse-on-timeout', {}.to_json
    assert last_response.unprocessable?
    assert_equal 7, JSON.parse(last_response.body).keys.size

    # invalid access_token
    post '/api/reverse-on-timeout', { access_token: 123, digest: 123, amount: amount, systan: systan,
                                      api_version: '1.0.0.', application_version: '1.0.0.', transaction_type: type}.to_json

    assert last_response.unprocessable?
    assert_equal 'unknown or disabled terminal', JSON.parse(last_response.body)['access_token'][0]

    # invalid digest
    post '/api/reverse-on-timeout', { access_token: terminal.access_token, digest: 123, amount: amount, systan: systan,
                                      api_version: '1.0.0.', application_version: '1.0.0.', transaction_type: type}.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['digest'][0]

    # reverse now
    post '/api/reverse-on-timeout', { access_token: terminal.access_token, digest: digest, amount: amount, systan: systan,
                                      api_version: '1.0.0.', application_version: '1.0.0.', transaction_type: type}.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)

    # check response
    assert_equal 'reversal is saved', resp['message']

    # counts
    reversal = Reversal.last
    assert_equal 1, Reversal.count
    assert_equal 1, reversal.account_dataset.count
    assert_equal 1, reversal.terminal_dataset.count

    # fields
    assert_equal amount, reversal.amount
    assert_equal account.currency, reversal.currency
    assert_equal systan.to_s, reversal.systan
    assert_equal terminal.services_batch_number, reversal.services_batch_number
    assert_equal 'top_up_mpos', reversal.transaction_type
    assert_equal '1.0.0.', reversal.api_version
    assert_equal '1.0.0.', reversal.application_version
  end

end

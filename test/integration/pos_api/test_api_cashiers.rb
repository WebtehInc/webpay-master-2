require_relative "../integration_helper"

class TestApiCashiers < Test

  def test_cashiers_api

    user = signup_user
    terminal = generate_terminal account_id: user.accounts.first.id

    # create regualar cashier
    login_user
    cashier, cashier_pin = create_cashier terminal

    full_name = 'Joe'
    digest   = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + full_name)


    # no payload
    post '/api/create-cashier', {}.to_json
    assert last_response.unprocessable?
    assert_equal 8, JSON.parse(last_response.body).keys.size

    # invalid access_token
    post '/api/create-cashier', {access_token: 'any', digest: 'any',
                                  api_version: '1.0.0.', application_version: '1.0.0.',
                                  cashier_pin: cashier_pin, manager_id: cashier.id}.to_json

    assert last_response.unprocessable?
    assert_equal 'unknown or disabled terminal', JSON.parse(last_response.body)['access_token'][0]

    # invalid digest
    post '/api/create-cashier', {access_token: terminal.access_token, digest: 'invalid',
                                  api_version: '1.0.0.', application_version: '1.0.0.',
                                  cashier_pin: cashier_pin, manager_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['digest'][0]

    # try with invalid pin
    post '/api/create-cashier', {access_token: terminal.access_token, digest: digest,
                                  api_version: '1.0.0.', application_version: '1.0.0.',
                                  full_name: full_name, manager: false, cashier_pin: 'wrong', manager_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'invalid manager pin', JSON.parse(last_response.body)['cashier_pin'][0]

    # try with cashier pin
    post '/api/create-cashier', {access_token: terminal.access_token, digest: digest,
                                  api_version: '1.0.0.', application_version: '1.0.0.',
                                  full_name: full_name, manager: false, cashier_pin: cashier_pin, manager_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'invalid manager pin', JSON.parse(last_response.body)['cashier_pin'][0]

    # try with inactive manager
    cashier.update(manager: true, active: false)
    post '/api/create-cashier', {access_token: terminal.access_token, digest: digest,
                                  api_version: '1.0.0.', application_version: '1.0.0.',
                                  full_name: full_name, manager: false, cashier_pin: cashier_pin, manager_id: cashier.id}.to_json
    assert last_response.unprocessable?
    assert_equal 'invalid manager pin', JSON.parse(last_response.body)['cashier_pin'][0]

    # do it now with active manager
    cashier.update(manager: true, active: true)
    post '/api/create-cashier', {access_token: terminal.access_token, digest: digest,
                                  api_version: '1.0.0.', application_version: '1.0.0.',
                                  full_name: full_name, manager: false, cashier_pin: cashier_pin, manager_id: cashier.id}.to_json
    assert last_response.ok?
    # test response fields
    resp = JSON.parse(last_response.body)
    assert_equal 4, resp['pin'].size
    resp_digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + resp['pin'])
    assert_equal resp_digest, resp['digest']

    # test cashier
    cashier1 = Cashier.last
    assert cashier1.active
    refute cashier1.manager

    # test relations
    assert_equal 2, terminal.cashiers.count


    # change pin for cashier1
    digest   = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + cashier1.id.to_s)

    # no payload
    puts '-------------------- NO PAYLOAD'
    post '/api/change-cashier-pin', {}
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal 7, resp.keys.size

    puts '-------------------- INVALID digest'
    post '/api/change-cashier-pin', {access_token: terminal.access_token, digest: '123',
                                      api_version: '1.0.0.', application_version: '1.0.0.',
                                      cashier_id: cashier1.id, cashier_pin: cashier_pin, manager_id: cashier.id}.to_json
    resp = JSON.parse(last_response.body)
    assert_equal 1, resp.keys.size
    assert resp['digest']


    puts '-------------------- INVALID cashier_id'
    invalid_cashier_id = 12345
    digest2   = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + invalid_cashier_id.to_s)

    post '/api/change-cashier-pin', {access_token: terminal.access_token, digest: digest2,
                                      api_version: '1.0.0.', application_version: '1.0.0.',
                                      cashier_id: invalid_cashier_id, cashier_pin: cashier_pin, manager_id: cashier.id}.to_json
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal 1, resp.keys.size
    assert resp['cashier_id']

    puts '-------------------- INVALID pin'
    post '/api/change-cashier-pin', {access_token: terminal.access_token, digest: digest,
                                      api_version: '1.0.0.', application_version: '1.0.0.',
                                      cashier_id: cashier1.id, cashier_pin: '0000', manager_id: cashier.id}.to_json
    resp = JSON.parse(last_response.body)
    assert last_response.unprocessable?
    assert_equal 1, resp.keys.size
    assert resp['cashier_pin']

    # unknown key
    post '/api/change-cashier-pin', {access_token: terminal.access_token, digest: digest,
                                      api_version: '1.0.0.', application_version: '1.0.0.',
                                      cashier_id: cashier1.id, cashier_pin: 'cashier_pin', id: 'key'}.to_json
    resp = JSON.parse(last_response.body)
    assert last_response.unprocessable?
    assert_equal 1, resp.keys.size
    assert resp['id'] # {:id=>"unknown key"}

    # change pin now
    post '/api/change-cashier-pin', {access_token: terminal.access_token, digest: digest,
                                      api_version: '1.0.0.', application_version: '1.0.0.',
                                      cashier_id: cashier1.id, cashier_pin: cashier_pin, manager_id: cashier.id}.to_json
    assert last_response.ok?
    # test response fields
    resp = JSON.parse(last_response.body)
    assert_equal 4, resp['pin'].size
    resp_digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + resp['pin'])
    assert_equal resp_digest, resp['digest']

    # update cashier

    # no payload
    post '/api/update-cashier', {}
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal 9, resp.keys.size

    # update now
    cashier.update(manager: true, active: true)
    post '/api/update-cashier', {access_token: terminal.access_token, digest: digest,
                                  api_version: '1.0.0.', application_version: '1.0.0.',
                                  cashier_id: cashier1.id, active: false , manager: true,
                                  cashier_pin: cashier_pin, manager_id: cashier.id}.to_json
    assert last_response.ok?
    # test response fields
    resp = JSON.parse(last_response.body)
    resp_digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + 'true')
    assert_equal resp_digest, resp['digest']

    # test cashier
    cashier1.reload
    refute cashier1.active
    assert cashier1.manager

    # create for inactive terminal
    terminal.update(active: false)
    post '/api/create-cashier', {access_token: terminal.access_token, digest: digest,
                                  api_version: '1.0.0.', application_version: '1.0.0.'}.to_json
    assert last_response.unprocessable?
    assert_equal 'unknown or disabled terminal', JSON.parse(last_response.body)['access_token'][0]



    #######################
    # check-cashier-pin API
    #######################

    Cashier.dataset.delete
    Terminal.dataset.delete

    terminal = generate_terminal account_id: user.accounts.first.id
    time = Time.now
    terminal.update(opening_hours: time.hour - 1, opening_minutes: time.min - 1,
                    closing_hours: time.hour + 1, closing_minutes: time.min + 1) # open store
    cashier, cashier_pin = create_cashier terminal
    digest   = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + cashier.id.to_s)

    # no payload
    puts '-------------------- NO PAYLOAD'
    post '/api/check-cashier-pin', {}
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal 6, resp.keys.size

    puts '-------------------- INVALID digest'
    post '/api/check-cashier-pin', {access_token: terminal.access_token, digest: '123',
                                    api_version: '1.0.0.', application_version: '1.0.0.',
                                    cashier_id: cashier.id, cashier_pin: cashier_pin}.to_json
    resp = JSON.parse(last_response.body)
    assert_equal 1, resp.keys.size
    assert resp['digest']


    puts '-------------------- INVALID cashier_id'
    invalid_cashier_id = 12345
    digest2   = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + invalid_cashier_id.to_s)
    post '/api/check-cashier-pin', {access_token: terminal.access_token, digest: digest2,
                                    api_version: '1.0.0.', application_version: '1.0.0.',
                                    cashier_id: invalid_cashier_id, cashier_pin: cashier_pin}.to_json
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal 1, resp.keys.size
    assert resp['cashier_pin']

    puts '-------------------- INVALID pin'
    post '/api/check-cashier-pin', {access_token: terminal.access_token, digest: digest,
                                    api_version: '1.0.0.', application_version: '1.0.0.',
                                    cashier_id: cashier.id, cashier_pin: '0000'}.to_json
    resp = JSON.parse(last_response.body)
    assert last_response.unprocessable?
    assert_equal 1, resp.keys.size
    assert resp['cashier_pin']

    # unknown key
    post '/api/check-cashier-pin', {access_token: terminal.access_token, digest: digest,
                                    api_version: '1.0.0.', application_version: '1.0.0.',
                                    cashier_id: cashier.id, cashier_pin: 'cashier_pin', id: 'key'}.to_json
    resp = JSON.parse(last_response.body)
    assert last_response.unprocessable?
    assert_equal 1, resp.keys.size
    assert resp['id'] # {:id=>"unknown key"}

    puts '-------------------- pin OK'
    post '/api/check-cashier-pin', {access_token: terminal.access_token, digest: digest,
                                    api_version: '1.0.0.', application_version: '1.0.0.',
                                    cashier_id: cashier.id, cashier_pin: cashier_pin}.to_json
    resp = JSON.parse(last_response.body)
    assert last_response.ok?
    # test response fields
    assert_equal 3, resp.keys.size
    resp_digest = Digest::SHA512.hexdigest(terminal.terminal_key + terminal.access_token + cashier_pin.to_s)
    assert_equal resp_digest, resp['digest']
  end

end

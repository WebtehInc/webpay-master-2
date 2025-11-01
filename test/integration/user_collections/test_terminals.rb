require_relative "../integration_helper"

class TestTerminals < Test

  def test_terminals
    unauthorized? :get, '/terminals/1'

    signup_user
    login_user

    account_id = Account.first.id
    generate_terminal account_id: account_id
    terminal_id = Terminal.first.id

    # get all terminals for accaount
    get "accounts/#{account_id}/terminals"
    assert last_response.ok?
    assert_equal 1, JSON.parse(last_response.body).size

    # cannot get previous terminals with other user
    signup_user email: 'second_user@webteh.us'
    login_user email: 'second_user@webteh.us'
    get "accounts/#{account_id}/terminals"
    assert last_response.ok?
    assert_equal [], JSON.parse(last_response.body)
  end

  def test_edit_terminal

    # disabled
    return

    user = signup_user
    login_user

    account_id  = Account.first.id
    terminal    = generate_terminal account_id: account_id
    terminal_id = terminal.id

    # requires otp
    post "/terminals/#{terminal_id}"
    assert last_response.forbidden?

    authorize_with_otp

    # no payload
    post "/terminals/#{terminal_id}"
    assert last_response.unprocessable?
    assert_equal 5, JSON.parse(last_response.body).keys.size # 5 errors

    # change merchant_name
    post "/terminals/#{terminal_id}", { merchant_name: 'Store', merchant_address: 'Address',
                                                      merchant_phone: '123455678', merchant_email: 'mail@mail.com',
                                                      receipt_text: '-'*10}.to_json
    assert last_response.ok?
    assert_equal 1, user.changes.count
    assert_equal 1, terminal.reload.config_version # incremented version

    # get audits
    get "/terminals/#{terminal_id}/changes"
    assert last_response.ok?
    assert_equal 1, JSON.parse(last_response.body).size # 1 audit
  end

  def test_cashiers
    user = signup_user
    login_user

    account_id  = Account.first.id
    terminal    = generate_terminal account_id: account_id
    terminal_id = terminal.id

    # empty payload
    post "/terminals/#{terminal_id}/cashiers/create", {}.to_json
    assert last_response.unprocessable?
    assert_equal 2, JSON.parse(last_response.body).keys.size

    # create cashier
    post "/terminals/#{terminal_id}/cashiers/create", {full_name: 'John Cashier', manager: true}.to_json
    assert last_response.ok?
    assert_equal 1, terminal.cashiers.count

    cashier = Cashier.first
    first_pin = JSON.parse(last_response.body)['pin']
    assert_equal 4, first_pin.size
    assert_equal true, cashier.manager
    assert_equal true, cashier.active

    # full_name exists
    # post "/terminals/#{terminal_id}/cashiers/create", {full_name: 'John Cashier', manager: true}.to_json
    # assert last_response.unprocessable?
    # assert_equal 'has already been taken', JSON.parse(last_response.body)['full_name'][0]

    # update cashier
    post "/terminals/#{terminal_id}/cashiers/#{cashier.id}", {manager: false, active: false}.to_json
    assert last_response.ok?

    cashier.reload
    assert_equal false, cashier.manager
    assert_equal false, cashier.active
    assert_equal Digest::SHA512.hexdigest(first_pin), cashier.hashed_pin # pin stays the same
    assert_equal 1, cashier.audits.count

    # generate new pin
    post "/terminals/#{terminal_id}/cashiers/#{cashier.id}/change-pin", {}.to_json
    assert last_response.ok?
    second_pin = JSON.parse(last_response.body)['pin']
    refute_equal first_pin, second_pin
    assert_equal 1, cashier.audits.count
  end

end

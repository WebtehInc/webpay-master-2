require_relative "../integration_helper"

class TestBuyVoucher < Test

  def test_buy_voucher

    unauthorized? :post, '/buy-voucher'

    user = signup_user
    login_user

    account = Account.first

    # requires otp
    forbidden? :post, '/buy-voucher'

    authorize_with_otp
    generate_operator

    # this product will trigger alert mail
    Product.create name: 'Chippie 100', price: 10000, currency: 'USD', type: 'voucher', operator_code: 'ch', notify_quantity: 1
    voucher_value = 'abcd'
    voucher = generate_voucher value: voucher_value, uid: 67890

    # no payload
    post '/buy-voucher', {}.to_json
    assert last_response.unprocessable?
    assert_equal 2, JSON.parse(last_response.body).keys.size # 2 errors

    # not enough funds
    post '/buy-voucher', { name: voucher.name, account_id: account.id }.to_json
    assert last_response.unprocessable?
    assert_equal ['not enough funds'], JSON.parse(last_response.body)['name']

    # buy it now
    account.update balance: 3*voucher.price
    post '/buy-voucher', { name: voucher.name, account_id: account.id }.to_json
    assert last_response.ok?

    # response json
    resp = JSON.parse(last_response.body)
    assert_equal voucher.name, resp['Name']
    assert_equal voucher.uid, resp['Serial']
    assert_equal voucher_value, resp['Code']
    assert resp['Info']

    account.reload
    trx = Transaction.first

    # check balance
    assert_equal 2*voucher.price, account.balance # we spent some money

    # check voucher status
    assert_equal 'sold', voucher.reload.status    # voucher is sold

    # transaction
    assert_equal voucher.price, trx.amount        # trx has amount
    assert_equal 'debit', trx.type                # trx is voucher type
    assert_equal 'voucher', trx.transaction_type  # trx is debit
    assert_equal account.balance, trx.balance     # reflect balance in trx
    assert_equal voucher.operator_code, trx.operator_code  # trx has operator code
    assert_equal voucher.name, trx.description
    assert_equal "Name: #{voucher.name} | Code: #{voucher_value} | Serial: #{voucher.uid}", trx.note

    # relations
    assert trx.voucher # trx has voucher
    assert_equal 1, user.transactions.count # trx has voucher

    # it is alredy sold, try again
    post '/buy-voucher', { name: voucher.name, account_id: account.id }.to_json
    assert last_response.unprocessable?
    assert_equal 'unknown voucher', JSON.parse(last_response.body)['name'][0]

    # buy with fee
    Fee.instance_eval {serializer file_path: './test/fixtures', file_name: "fees.json"}
    Fee.send(:save_to_db_from_file!, true)

    voucher = generate_voucher operator_code: 'ch', uid: 2, name: 'Chippie 5', batch_number: 2, status: 'available', price: 500, currency: 'USD'
    post '/buy-voucher', { name: voucher.name, account_id: account.id }.to_json
    assert last_response.ok?

    assert_equal 3, Transaction.count

    fee_trx = Transaction.last
    fee_amount = Fee.where(transaction_type: 'voucher', user_type: user.type, account_type: account.type).first.amount
    assert_equal fee_amount, fee_trx.amount

    old_balance = account.balance
    assert_equal old_balance - 500 - fee_amount, account.reload.balance

  end

end

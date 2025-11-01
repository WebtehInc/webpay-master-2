require_relative "../integration_helper"

class TestWalletToWalletTransfer < Test

  def test_wallet_to_wallet_transfer
    unauthorized? :post, '/transfer'

    target_user = signup_user(email: 'second@email.com')
    source_user = signup_user
    login_user

    source_account = source_user.accounts.first
    target_account = target_user.accounts.first

    # requires otp
    post 'transfer'
    assert last_response.forbidden?
    authorize_with_otp(source_user)

    # no payload
    post 'transfer'
    assert last_response.unprocessable?
    assert_equal 5, JSON.parse(last_response.body).keys.size # 5 errors

    transfer_amount = 12345
    starting_balance = transfer_amount + 100000
    ending_balance = starting_balance - transfer_amount

    # invalid target account by id
    post 'transfer', {  source_account_id: source_account.id, target_account_id: target_account.account_number + '10',
                        amount: transfer_amount, currency: 'USD'}.to_json
    assert last_response.unprocessable?
    assert_equal ['unknown target account'], JSON.parse(last_response.body)['target_account_id']

    # invalid target account by currency
    post 'transfer', {  source_account_id: source_account.id, target_account_id: target_account.account_number,
                        amount: transfer_amount, currency: 'EUR'}.to_json
    assert last_response.unprocessable?
    assert_equal ['unknown target account'], JSON.parse(last_response.body)['target_account_id']

    # not enough funds
    post 'transfer', {  source_account_id: source_account.id, target_account_id: target_account.account_number,
                        amount: transfer_amount, currency: 'USD'}.to_json
    assert last_response.unprocessable?
    assert_equal ['not enough funds'], JSON.parse(last_response.body)['amount']

    # transfer ok
    source_account.update(balance: starting_balance) # add money
    post 'transfer', {  source_account_id: source_account.id, target_account_id: target_account.account_number,
                        amount: transfer_amount, currency: 'USD', note: 'Transfer note'}.to_json
    assert last_response.ok?

    assert_equal 2, Transaction.count

    # refresh accounts from db
    source_account.reload
    target_account.reload

    # debit account
    assert_equal ending_balance, source_account.balance

    # debit trx
    debit_trx = source_account.transactions.first
    assert_equal transfer_amount, debit_trx.amount
    assert_equal source_account.balance, debit_trx.balance  # reflect balance in trx
    assert_equal 'transfer', debit_trx.transaction_type     # check fields
    assert_equal 'debit', debit_trx.type
    assert_equal 'approved',debit_trx.status


    # credit account
    assert_equal transfer_amount, target_account.balance

    # credit trx
    credit_trx = target_account.transactions.first
    assert_equal transfer_amount, credit_trx.amount
    assert_equal target_account.balance, credit_trx.balance # reflect balance in trx
    assert_equal 'transfer', credit_trx.transaction_type    # check fields
    assert_equal 'credit', credit_trx.type
    assert_equal 'approved', credit_trx.status

    # relations
    assert_equal debit_trx.id, credit_trx.parent_id
    assert_equal 1, source_account.transactions.count
    assert_equal 1, target_account.transactions.count
    assert_equal 1, source_user.transactions.count
    assert_equal 1, target_user.transactions.count

    # transfer with fee
    Fee.instance_eval {serializer file_path: './test/fixtures', file_name: "fees.json"}
    Fee.send(:save_to_db_from_file!, true)

    transfer_amount = 123
    post 'transfer', {  source_account_id: source_account.id, target_account_id: target_account.account_number,
                        amount: transfer_amount, currency: 'USD', note: 'Transfer note'}.to_json
    assert last_response.ok?

    assert_equal 5, Transaction.count

    fee_trx = Transaction.last
    fee_amount = Fee.where(transaction_type: 'transfer', user_type: source_user.type, account_type: source_account.type).first.amount
    assert_equal fee_amount, fee_trx.amount

    old_balance = source_account.balance
    assert_equal old_balance - transfer_amount - fee_amount, source_account.reload.balance

    assert_equal 3, source_account.transactions.count
  end

end

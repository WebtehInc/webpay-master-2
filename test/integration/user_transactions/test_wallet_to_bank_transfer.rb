require_relative "../integration_helper"

class TestWalletToBankTransfer < Test

  def test_wallet_to_bank_transfer
    unauthorized? :post, 'transfer/wallet-to-bank'

    user = signup_user
    login_user

    wallet_account = user.accounts.first # wallet personal acc
    bank_account = generate_bank_account user, 'current'

    # requires otp
    post 'transfer/wallet-to-bank'
    assert last_response.forbidden?
    authorize_with_otp(user)

    # no payload
    post 'transfer/wallet-to-bank'
    assert last_response.unprocessable?
    assert_equal 5, JSON.parse(last_response.body).keys.size # 5 errors

    transfer_amount = 12345
    starting_balance = transfer_amount + 100000
    ending_balance = starting_balance - transfer_amount

    # not enough funds
    post 'transfer/wallet-to-bank', { source_account_id: wallet_account.id, target_account_id: bank_account.id,
                                      amount: transfer_amount, currency: wallet_account.currency, note: ''}.to_json
    assert last_response.unprocessable?
    assert_equal ['not enough funds'], JSON.parse(last_response.body)['amount']

    # transfer ok
    wallet_account.update(balance: starting_balance) # add money
    post 'transfer/wallet-to-bank', { source_account_id: wallet_account.id, target_account_id: bank_account.id,
                                      amount: transfer_amount, currency: wallet_account.currency, note: ''}.to_json
    assert last_response.ok?

    # error, amount == 300 in mock
    post 'transfer/wallet-to-bank', { source_account_id: wallet_account.id, target_account_id: bank_account.id,
                                      amount: 300, currency: wallet_account.currency, note: ''}.to_json
    assert last_response.unprocessable?
    assert_equal ['no response from host'], JSON.parse(last_response.body)['amount']

    # decline, amount == 200 in mock
    post 'transfer/wallet-to-bank', { source_account_id: wallet_account.id, target_account_id: bank_account.id,
                                      amount: 200, currency: wallet_account.currency, note: ''}.to_json
    assert last_response.unprocessable?
    assert_equal 'declined', JSON.parse(last_response.body)['status']

    # counts
    assert_equal 2, Transaction.count

    # debit wallet account
    assert_equal ending_balance, wallet_account.reload.balance

    # debit trx
    debit_trx = wallet_account.transactions.first
    assert_equal transfer_amount, debit_trx.amount
    assert_equal wallet_account.balance, debit_trx.balance              # reflect balance in trx
    assert_equal 'transfer_wallet_to_bank', debit_trx.transaction_type  # check fields
    assert_equal 'debit', debit_trx.type
    assert_equal 'approved', debit_trx.status


    # remote bank account manage its balance
    # assert_equal bank_account.balance, bank_account.reload.balance

    # credit trx
    credit_trx = bank_account.transactions.first
    assert_equal transfer_amount, credit_trx.amount
    assert_equal bank_account.reload.balance, credit_trx.balance        # reflect balance in trx
    assert_equal 'transfer_wallet_to_bank', credit_trx.transaction_type # check fields
    assert_equal 'credit', credit_trx.type
    assert_equal 'approved', credit_trx.status

    # relations
    assert_equal debit_trx.id, credit_trx.parent_id
    assert_equal 1, wallet_account.transactions.count
    assert_equal 1, bank_account.transactions.count
    assert_equal 2, user.transactions.count

    # transfer with fee
    Fee.instance_eval {serializer file_path: './test/fixtures', file_name: "fees.json"}
    Fee.send(:save_to_db_from_file!, true)

    transfer_amount = 123
    post 'transfer/wallet-to-bank', { source_account_id: wallet_account.id, target_account_id: bank_account.id,
                                      amount: transfer_amount, currency: wallet_account.currency, note: ''}.to_json
    assert last_response.ok?

    assert_equal 5, Transaction.count

    fee_trx = Transaction.last
    fee_amount = Fee.where(transaction_type: 'transfer_wallet_to_bank', user_type: user.type, account_type: wallet_account.type).first.amount
    assert_equal fee_amount, fee_trx.amount

    old_balance = wallet_account.balance
    assert_equal old_balance - transfer_amount - fee_amount, wallet_account.reload.balance

    assert_equal 3, wallet_account.transactions.count
  end

end

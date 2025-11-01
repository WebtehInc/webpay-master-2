require_relative "../integration_helper"

class TestBankBalanceInquiry < Test

  def test_bank_balance_inquiry
    unauthorized? :post, 'transfer/bank-balance-inquiry'

    user = signup_user
    login_user

    bank_account = generate_bank_account user, 'current'

    # requires otp
    post 'transfer/bank-balance-inquiry'
    assert last_response.forbidden?
    authorize_with_otp(user)

    # no payload
    post 'transfer/bank-balance-inquiry'
    assert last_response.unprocessable?
    assert_equal 1, JSON.parse(last_response.body).keys.size # 1 error

    # balance inquiry ok
    post 'transfer/bank-balance-inquiry', { account_id: bank_account.id }.to_json
    assert last_response.ok?

    # counts
    assert_equal 1, Transaction.count

    # debit trx with zero amount
    debit_trx = bank_account.transactions.first
    assert_equal 0, debit_trx.amount
    assert_equal bank_account.reload.balance, debit_trx.balance      # reflect balance in trx
    assert_equal 'bank_balance_inquiry', debit_trx.transaction_type  # check fields
    assert_equal 'debit', debit_trx.type
    assert_equal 'approved', debit_trx.status

    # update balance
    assert_equal debit_trx.balance, bank_account.reload.balance

    # relations
    assert_equal 1, bank_account.transactions.count
    assert_equal 1, user.transactions.count

  end

end

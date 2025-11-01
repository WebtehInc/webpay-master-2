require_relative "../integration_helper"

class TestLimitsForTransfer < Test

  def test_source_account_limits_for_transfer

    target_user = signup_user(email: 'second@email.com')
    source_user = signup_user
    login_user

    source_account = source_user.accounts.first
    target_account = target_user.accounts.first

    authorize_with_otp(source_user)

    source_account.update balance: 50000

    # import limit fixtures
    Limit.instance_eval {serializer file_path: './test/fixtures', file_name: "limits.json"}
    Limit.send(:save_to_db_from_file!, true)

    # make 3 transfers; limit is 3 in fixtures
    amount = 100
    transfer(source_account, target_account, amount)
    transfer(source_account, target_account, amount)
    transfer(source_account, target_account, amount)

    # limit now by count
    decline_transfer(source_account, target_account, amount, 'amount', LIMIT_COUNT_MSG)

    # reset counts
    Transaction.dataset.delete

    # make 2 transfers for 20000; limit is 21000 in fixtures
    amount = 10000
    transfer(source_account, target_account, amount)
    transfer(source_account, target_account, amount)

    # limit now by volume
    decline_transfer(source_account, target_account, amount, 'amount', LIMIT_VOLUME_MSG)

  end


  def test_target_account_limits_for_transfer

    target_user = signup_user(email: 'second@email.com')
    source_user = signup_user
    login_user

    source_account = source_user.accounts.first
    target_account = target_user.accounts.first

    authorize_with_otp(source_user)

    source_account.update balance: 50000

    # import limit fixtures
    Limit.instance_eval {serializer file_path: './test/fixtures', file_name: "limits.json"}
    Limit.send(:save_to_db_from_file!, true)

    # delete limits for source account
    Limit.where(id: [31, 32, 33, 34]).delete

    # make 3 transfers; limit is 3 in fixtures
    amount = 100
    transfer(source_account, target_account, amount)
    transfer(source_account, target_account, amount)
    transfer(source_account, target_account, amount)

    # limit now by count
    decline_transfer(source_account, target_account, amount, 'target_account_id', LIMIT_COUNT_MSG_FOR_TARGET_ACCOUNT)

    # reset counts
    Transaction.dataset.delete

    # make 2 transfers for 20000; limit is 21000 in fixtures
    amount = 10000
    transfer(source_account, target_account, amount)
    transfer(source_account, target_account, amount)

    # limit now by volume
    decline_transfer(source_account, target_account, amount, 'target_account_id', LIMIT_VOLUME_MSG_FOR_TARGET_ACCOUNT)
  end

  # helpers for approve/decline
  def transfer(source_account, target_account, amount)
    post 'transfer', {  source_account_id: source_account.id, target_account_id: target_account.account_number,
                        amount: amount, currency: 'USD', note: 'Transfer note'}.to_json
    assert last_response.ok?
  end

  def decline_transfer(source_account, target_account, amount, resp_attr, resp_msg)
    post 'transfer', {  source_account_id: source_account.id, target_account_id: target_account.account_number,
                        amount: amount, currency: 'USD', note: 'Transfer note'}.to_json
    assert last_response.unprocessable?
    assert_equal resp_msg, JSON.parse(last_response.body)[resp_attr][0]
  end

end

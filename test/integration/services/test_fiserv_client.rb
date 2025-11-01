require_relative "../integration_helper"
require 'pry'

module Gateway
  class FiservClientTest < Test

    def setup
      super
      @request_count = 0
      # VCR.eject_cassette if VCR.current_cassette
      # VCR.turn_off!
    end

    def test_balance_success
      rv = PagafasilImporters::FiservClient.new.balance 'DD', '9900003588'
      assert_status rv, 'approved'
      assert_balances rv
    end

    # def test_balance_success_with_GL_account
    #   rv = PagafasilImporters::FiservClient.new.balance 'GL', '270900000006'
    #   assert_status rv, 'approved'
    #   assert_balances rv
    # end

    def test_balance_failure
      rv = PagafasilImporters::FiservClient.new.balance 'DD', '9900003588AAAAA'
      assert_status rv, 'declined'
      assert_equal 'PS10032', rv[:response_code], 'response_code is off'
      assert_equal 'Invalid account number.', rv[:response_message], 'response_message is off'
      assert_equal Hash, rv[:general_status].class, 'general status is off'
    end

    def test_transfer_success_DD_to_DD
      src_acct_balance = get_balance('DD', '9900003588')
      dest_acct_balance = get_balance('DD', '9900003589')
      rv = PagafasilImporters::FiservClient.new.transfer rand(10**12), 'DD', '9900003588', 'DD', '9900003589', 1, 'ANG'
      assert_status rv, 'approved'
      assert_equal src_acct_balance-1, get_balance('DD', '9900003588'), 'src balance is off'
      assert_equal dest_acct_balance+1, get_balance('DD', '9900003589'), 'dest balance is off'
    end

    def test_transfer_success_GL_to_DD
      dest_acct_balance = get_balance('DD', '9900003588')
      rv = PagafasilImporters::FiservClient.new.transfer rand(10**12), 'GL', '270900000006', 'DD', '9900003588', 1, 'ANG'
      assert_status rv, 'approved'
      assert_equal dest_acct_balance+1, get_balance('DD', '9900003588'), 'dest balance is off'
    end

    def test_transfer_success_DD_to_GL
      src_acct_balance = get_balance('DD', '9900003588')
      rv = PagafasilImporters::FiservClient.new.transfer rand(10**12), 'DD', '9900003588', 'GL', '270900000006', 1, 'ANG'
      assert_status rv, 'approved'
      assert_equal src_acct_balance-1, get_balance('DD', '9900003588'), 'src balance is off'
    end

    def test_transfer_failure
      rv = PagafasilImporters::FiservClient.new.transfer rand(10**12), 'DD', '9900003588', 'DD', '9900003589', 1000000000000, 'ANG'
      assert_status rv, 'declined'
      assert_equal 'declined', rv[:status], 'status is off'
      assert_equal 'PS10050', rv[:response_code], 'response_code is off'
      assert_equal 'Non-Sufficient Funds', rv[:response_message], 'response_message is off'
      assert_equal Hash, rv[:general_status].class, 'general status is off'
    end


    private

    def assert_status response, exp
      assert_equal exp, response[:status], "status is off, response is #{response[:general_status]}"
    end

    def assert_balances rv
      assert_equal 2, rv[:balances].count, "number of #{rv[:balances]} is off"

      current_balance = rv[:balances].select{|k| k[:type] == 'current'}.first
      assert current_balance, "no current_balance in #{rv[:balances]}"
      assert_equal 'ANG', current_balance[:currency], 'current_balance currency is off'
      assert current_balance[:amount] > 0, 'current_balance amount is off'

      available_balance = rv[:balances].select{|k| k[:type] == 'available'}.first
      assert available_balance, "no available_balance in #{rv[:balances]}"
      assert_equal 'ANG', available_balance[:currency], 'available_balance currency is off'
      assert available_balance[:amount] > 0, 'available_balance amount is off'
    end

    def get_balance acct_type, acct_id
      @request_count += 1
      # VCR.eject_cassette if VCR.current_cassette
      # VCR.insert_cassette(@__vcr_cassette_name + ".#{@request_count}")

      PagafasilImporters::FiservClient.new.
        balance(acct_type, acct_id)[:balances].
        select{|k| k[:type] == 'available'}.
        first[:amount]
    end

  end
end

require_relative "../integration_helper"

module Gateway
  class PagatinuClientTest < Test

    def setup
      super
    end

    # OLD RESPONSE:
    #
    # {:status=>"approved",
    #   :message=>"Credit Purchase successful",
    #   :receipt_no=>"VUPSB/2366428",
    #   :token=>"01234567890123456789",
    #   :units=>"2632 KWh",
    #   :resource=>"electricity",
    #   :cust_vend_acct=>"93000",
    #   :cust_vend_name=>"CU 3, T",
    #   :meter_number=>"04111111110",
    #   :tariff_rate_amount=>"0.76",
    #   :tariff_rate_currency=>"XCG",
    #   :tariff_name=>"DOMESTICO"}

    # NEW RESPONSE:
    # { :status=>"approved",
    #   :message=>"Credit Purchase successful",
    #   :receipt_no=>"VUPSB/3994500",
    #   :token=>"32678132995057592063",
    #   :units=>"36.3 KWh",
    #   :resource=>"electricity",
    #   :cust_vend_acct=>"11179600",
    #   :cust_vend_name=>"JULIANA SIGNALD  A",
    #   :meter_number=>"04155183447",
    #   :tariff_name=>"DOMESTICO",
    #   :tariff_rates=>[{:amount=>"0.60", :currency=>"XCG"}, {:amount=>"0.64", :currency=>"XCG"}]}


    def test_success
      rv = PagafasilImporters::MockPagatinuClient.mock! meter_no: '04111111110', amount: 2000_00
      assert_equal 'approved', rv[:status], 'status is wrong'
      assert_equal 'Credit Purchase successful', rv[:message], 'message is wrong'
      assert_equal 1, rv[:tariff_rates].count
    end

    def test_success_with_multiple_tariffs
      rv = PagafasilImporters::MockPagatinuClient.mock! meter_no: '04111111110', amount: 210_00
      assert_equal 'approved', rv[:status], 'status is wrong'
      assert_equal 'Credit Purchase successful', rv[:message], 'message is wrong'
      assert_equal 2, rv[:tariff_rates].count
    end

    # {:status=>"declined", :message=>"meter_no is invalid"}
    def test_invalid_meter_number
      rv = PagafasilImporters::MockPagatinuClient.mock! meter_no: '041111111101', amount: 2000_00
      assert_equal 'declined', rv[:status], 'status is wrong'
      assert_equal 'meter number is invalid', rv[:message], 'message is wrong'
    end

    # {:status=>"declined", :message=>"Meter Not Found"}
    def test_meter_not_found
      rv = PagafasilImporters::MockPagatinuClient.mock! meter_no: '041111111104', amount: 2000_00
      assert_equal 'declined', rv[:status], 'status is wrong'
      assert_equal 'Meter Not Found', rv[:message], 'message is wrong'
    end

  end
end

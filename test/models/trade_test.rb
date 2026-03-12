require "test_helper"

class TradeTest < ActiveSupport::TestCase
  test "build_name generates buy trade name" do
    name = Trade.build_name("buy", 10, "AAPL")
    assert_equal "Buy 10.0 shares of AAPL", name
  end

  test "build_name generates sell trade name" do
    name = Trade.build_name("sell", 5, "MSFT")
    assert_equal "Sell 5.0 shares of MSFT", name
  end

  test "build_name handles absolute value for negative quantities" do
    name = Trade.build_name("sell", -5, "GOOGL")
    assert_equal "Sell 5.0 shares of GOOGL", name
  end

  test "build_name handles decimal quantities" do
    name = Trade.build_name("buy", 0.25, "BTC")
    assert_equal "Buy 0.25 shares of BTC", name
  end

  test "price scale is preserved at 10 decimal places" do
    security = Security.create!(ticker: "TEST", exchange_operating_mic: "XNAS")

    # up to 10 decimal places — should persist exactly
    precise_price = BigDecimal("12.3456789012")
    trade = Trade.create!(
      security: security,
      price: precise_price,
      qty: 10000,
      currency: "USD",
      investment_activity_label: "Buy"
    )

    trade.reload

    assert_equal precise_price, trade.price
  end

  test "price is rounded to 10 decimal places" do
    security = Security.create!(ticker: "TEST", exchange_operating_mic: "XNAS")

    # over 10 decimal places — will be rounded
    price_with_too_many_decimals = BigDecimal("1.123456789012345")
    trade = Trade.create!(
      security: security,
      price: price_with_too_many_decimals,
      qty: 1,
      currency: "USD",
      investment_activity_label: "Buy"
    )

    trade.reload

    assert_equal BigDecimal("1.1234567890"), trade.price
  end

  test "fee is stored and accessible" do
    security = Security.create!(ticker: "FEETEST", exchange_operating_mic: "XNAS")
    trade = Trade.create!(
      security: security,
      price: BigDecimal("100.00"),
      qty: 10,
      currency: "USD",
      investment_activity_label: "Buy",
      fee: BigDecimal("9.99"),
      fee_currency: "USD"
    )

    trade.reload

    assert_equal BigDecimal("9.99"), trade.fee
    assert_equal "USD", trade.fee_currency
    assert_equal Money.new(BigDecimal("9.99")), trade.fee_money
  end

  test "tax is stored and accessible" do
    security = Security.create!(ticker: "TAXTEST", exchange_operating_mic: "XNAS")
    trade = Trade.create!(
      security: security,
      price: BigDecimal("100.00"),
      qty: -5,
      currency: "USD",
      investment_activity_label: "Sell",
      tax: BigDecimal("15.00"),
      tax_currency: "USD"
    )

    trade.reload

    assert_equal BigDecimal("15.00"), trade.tax
    assert_equal "USD", trade.tax_currency
    assert_equal Money.new(BigDecimal("15.00")), trade.tax_money
  end

  test "fee and tax are optional" do
    security = Security.create!(ticker: "NOFEE", exchange_operating_mic: "XNAS")
    trade = Trade.create!(
      security: security,
      price: BigDecimal("100.00"),
      qty: 10,
      currency: "USD",
      investment_activity_label: "Buy"
    )

    trade.reload

    assert_nil trade.fee
    assert_nil trade.tax
    assert_nil trade.fee_money
    assert_nil trade.tax_money
  end

  test "fee must be non-negative" do
    security = Security.create!(ticker: "NEGFEE", exchange_operating_mic: "XNAS")
    trade = Trade.new(
      security: security,
      price: BigDecimal("100.00"),
      qty: 10,
      currency: "USD",
      investment_activity_label: "Buy",
      fee: BigDecimal("-1.00")
    )

    assert_not trade.valid?
    assert_includes trade.errors[:fee], "must be greater than or equal to 0"
  end

  test "tax must be non-negative" do
    security = Security.create!(ticker: "NEGTAX", exchange_operating_mic: "XNAS")
    trade = Trade.new(
      security: security,
      price: BigDecimal("100.00"),
      qty: -5,
      currency: "USD",
      investment_activity_label: "Sell",
      tax: BigDecimal("-5.00")
    )

    assert_not trade.valid?
    assert_includes trade.errors[:tax], "must be greater than or equal to 0"
  end

  test "unrealized_gain_loss includes fee in cost basis" do
    security = Security.create!(ticker: "UNREAL", exchange_operating_mic: "XNAS")
    Security::Price.create!(security: security, date: Date.current, price: BigDecimal("120.00"))

    trade = Trade.new(
      security: security,
      price: BigDecimal("100.00"),
      qty: 10,
      currency: "USD",
      investment_activity_label: "Buy",
      fee: BigDecimal("10.00"),
      fee_currency: "USD"
    )

    security.stubs(:current_price).returns(Money.new(BigDecimal("120.00")))

    gain_loss = trade.unrealized_gain_loss

    # current_value = 120 * 10 = 1200
    # cost_basis = (100 * 10) + 10 = 1010
    # unrealized gain = 1200 - 1010 = 190
    assert_equal Money.new(BigDecimal("190.00")), gain_loss.value
  end

  test "unrealized_gain_loss without fee uses price only" do
    security = Security.create!(ticker: "UNREAL2", exchange_operating_mic: "XNAS")

    trade = Trade.new(
      security: security,
      price: BigDecimal("100.00"),
      qty: 10,
      currency: "USD",
      investment_activity_label: "Buy"
    )

    security.stubs(:current_price).returns(Money.new(BigDecimal("120.00")))

    gain_loss = trade.unrealized_gain_loss

    # current_value = 120 * 10 = 1200
    # cost_basis = 100 * 10 = 1000
    # unrealized gain = 200
    assert_equal Money.new(BigDecimal("200.00")), gain_loss.value
  end
end

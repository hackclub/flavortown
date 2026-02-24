# frozen_string_literal: true

require "test_helper"

class Shop::CalculateFulfillmentPayoutsJobTest < ActiveJob::TestCase
  setup do
    @fulfiller = User.create!(slack_id: "UFULFILL1", display_name: "Fulfiller One", email: "fulfiller1@test.com")
    @fulfiller2 = User.create!(slack_id: "UFULFILL2", display_name: "Fulfiller Two", email: "fulfiller2@test.com")
    @buyer = User.create!(slack_id: "UBUYER1", display_name: "Buyer One", email: "buyer1@test.com")

    @item = ShopItem.create!(name: "Test Item", ticket_cost: 0, type: "ShopItem::ThirdPartyPhysical", enabled: true)

    @order1 = create_fulfilled_order(@buyer, @item, @fulfiller)
    @order2 = create_fulfilled_order(@buyer, @item, @fulfiller)
    @order3 = create_fulfilled_order(@buyer, @item, @fulfiller2)
  end

  test "creates a payout run with correct totals" do
    Shop::CalculateFulfillmentPayoutsJob.perform_now

    run = FulfillmentPayoutRun.last
    assert_equal "pending_approval", run.aasm_state
    assert_equal 3, run.total_orders
    assert_equal 9, run.total_amount # 3 orders × 3 tickets
  end

  test "creates payout lines grouped by fulfiller" do
    Shop::CalculateFulfillmentPayoutsJob.perform_now

    run = FulfillmentPayoutRun.last
    assert_equal 2, run.lines.count

    fulfiller1_line = run.lines.find_by(user: @fulfiller)
    assert_equal 2, fulfiller1_line.order_count
    assert_equal 6, fulfiller1_line.amount

    fulfiller2_line = run.lines.find_by(user: @fulfiller2)
    assert_equal 1, fulfiller2_line.order_count
    assert_equal 3, fulfiller2_line.amount
  end

  test "associates orders with their payout lines" do
    Shop::CalculateFulfillmentPayoutsJob.perform_now

    run = FulfillmentPayoutRun.last
    fulfiller1_line = run.lines.find_by(user: @fulfiller)

    assert_equal fulfiller1_line.id, @order1.reload.fulfillment_payout_line_id
    assert_equal fulfiller1_line.id, @order2.reload.fulfillment_payout_line_id
  end

  test "skips orders already paid out" do
    Shop::CalculateFulfillmentPayoutsJob.perform_now
    assert_equal 1, FulfillmentPayoutRun.count

    # Add a new order and run again
    create_fulfilled_order(@buyer, @item, @fulfiller)
    Shop::CalculateFulfillmentPayoutsJob.perform_now

    assert_equal 2, FulfillmentPayoutRun.count
    second_run = FulfillmentPayoutRun.order(:created_at).last
    assert_equal 1, second_run.total_orders
  end

  test "skips orders without assigned_to_user" do
    unassigned = ShopOrder.create!(
      user: @buyer,
      shop_item: @item,
      quantity: 1,
      frozen_item_price: 0,
      frozen_address: { "country" => "US" }.to_json,
      aasm_state: "fulfilled",
      fulfilled_at: Time.current,
      assigned_to_user_id: nil
    )

    Shop::CalculateFulfillmentPayoutsJob.perform_now

    run = FulfillmentPayoutRun.last
    assert_equal 3, run.total_orders # only the 3 assigned orders
    assert_nil unassigned.reload.fulfillment_payout_line_id
  end

  test "does nothing when no eligible orders" do
    ShopOrder.update_all(aasm_state: "pending")

    Shop::CalculateFulfillmentPayoutsJob.perform_now

    assert_equal 0, FulfillmentPayoutRun.count
  end

  test "manual run only includes orders since last run" do
    # First scheduled run covers all orders
    Shop::CalculateFulfillmentPayoutsJob.perform_now
    first_run = FulfillmentPayoutRun.last

    # New order fulfilled after the first run
    new_order = create_fulfilled_order(@buyer, @item, @fulfiller, fulfilled_at: 1.hour.from_now)

    # Old order that was fulfilled before the first run but wasn't included (simulate by removing payout line)
    old_order = create_fulfilled_order(@buyer, @item, @fulfiller2, fulfilled_at: 1.week.ago)

    # Manual run should only pick up new_order (fulfilled after last run's period_end)
    Shop::CalculateFulfillmentPayoutsJob.perform_now(manual: true)

    second_run = FulfillmentPayoutRun.order(:created_at).last
    assert_equal 1, second_run.total_orders
    assert_not_nil new_order.reload.fulfillment_payout_line_id
    assert_nil old_order.reload.fulfillment_payout_line_id
  end

  private

  def create_fulfilled_order(buyer, item, fulfiller, fulfilled_at: Time.current)
    ShopOrder.create!(
      user: buyer,
      shop_item: item,
      quantity: 1,
      frozen_item_price: 0,
      frozen_address: { "country" => "US" }.to_json,
      aasm_state: "fulfilled",
      fulfilled_at: fulfilled_at,
      fulfilled_by: fulfiller.display_name,
      assigned_to_user_id: fulfiller.id
    )
  end
end

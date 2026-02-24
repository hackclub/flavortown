# frozen_string_literal: true

# == Schema Information
#
# Table name: fulfillment_payout_runs
#
#  id                  :bigint           not null, primary key
#  aasm_state          :string
#  approved_at         :datetime
#  period_end          :datetime
#  period_start        :datetime
#  total_amount        :integer
#  total_orders        :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  approved_by_user_id :bigint
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_user_id => users.id)
#
require "test_helper"

class FulfillmentPayoutRunTest < ActiveSupport::TestCase
  setup do
    @fulfiller = User.create!(slack_id: "UPAYOUT1", display_name: "Payout Fulfiller", email: "payout@test.com")
    @admin = User.create!(slack_id: "UADMIN1", display_name: "Admin User", email: "admin@test.com", granted_roles: [ :admin ])
    @item = ShopItem.create!(name: "Payout Item", ticket_cost: 0, type: "ShopItem::ThirdPartyPhysical", enabled: true)
    @buyer = User.create!(slack_id: "UBUYER2", display_name: "Buyer Two", email: "buyer2@test.com")
  end

  test "approve creates ledger entries for each line" do
    run = create_payout_run_with_lines

    run.approved_by_user = @admin
    run.approved_at = Time.current
    run.approve!

    assert_equal "approved", run.aasm_state
    assert_equal 1, @fulfiller.ledger_entries.where(ledgerable_type: "FulfillmentPayoutLine").count

    entry = @fulfiller.ledger_entries.where(ledgerable_type: "FulfillmentPayoutLine").first
    assert_equal 6, entry.amount
    assert_includes entry.reason, "2 orders"
  end

  test "reject releases orders back for next run" do
    run = create_payout_run_with_lines
    line = run.lines.first
    order_ids = ShopOrder.where(fulfillment_payout_line: line).pluck(:id)

    run.reject!

    assert_equal "rejected", run.aasm_state
    order_ids.each do |order_id|
      assert_nil ShopOrder.find(order_id).fulfillment_payout_line_id
    end
  end

  test "tickets per order is 3" do
    assert_equal 3, FulfillmentPayoutRun::TICKETS_PER_ORDER
  end

  private

  def create_payout_run_with_lines
    run = FulfillmentPayoutRun.create!(
      period_end: Time.current,
      total_orders: 2,
      total_amount: 6
    )

    line = run.lines.create!(user: @fulfiller, order_count: 2, amount: 6)

    2.times do
      ShopOrder.create!(
        user: @buyer,
        shop_item: @item,
        quantity: 1,
        frozen_item_price: 0,
        frozen_address: { "country" => "US" }.to_json,
        aasm_state: "fulfilled",
        fulfilled_at: Time.current,
        fulfilled_by: @fulfiller.display_name,
        assigned_to_user_id: @fulfiller.id,
        fulfillment_payout_line: line
      )
    end

    run
  end
end

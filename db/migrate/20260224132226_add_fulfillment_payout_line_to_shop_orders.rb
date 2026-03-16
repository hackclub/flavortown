class AddFulfillmentPayoutLineToShopOrders < ActiveRecord::Migration[8.1]
  def change
    add_reference :shop_orders, :fulfillment_payout_line, null: true, foreign_key: true
  end
end

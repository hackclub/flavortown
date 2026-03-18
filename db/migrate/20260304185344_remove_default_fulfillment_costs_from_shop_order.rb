class RemoveDefaultFulfillmentCostsFromShopOrder < ActiveRecord::Migration[8.1]
  def change
    change_column_default :shop_orders, :fulfillment_cost, nil
  end
end

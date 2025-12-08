class AddIndexToShopOrdersShopCardGrantId < ActiveRecord::Migration[8.1]
  def change
    add_index :shop_orders, :shop_card_grant_id
  end
end

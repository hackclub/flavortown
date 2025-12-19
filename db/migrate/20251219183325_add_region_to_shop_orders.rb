class AddRegionToShopOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_orders, :region, :string, limit: 2
    add_index :shop_orders, :region
  end
end

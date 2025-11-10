class RemoveFrozenAddressFromShopOrders < ActiveRecord::Migration[8.1]
  def change
    remove_column :shop_orders, :frozen_address, :jsonb
  end
end

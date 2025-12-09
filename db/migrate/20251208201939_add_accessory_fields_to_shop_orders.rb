class AddAccessoryFieldsToShopOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_orders, :accessory_ids, :bigint, array: true, default: []
    add_reference :shop_orders, :parent_order, foreign_key: { to_table: :shop_orders }, null: true
  end
end

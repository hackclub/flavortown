class AddAssignedToUserToShopOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_orders, :assigned_to_user_id, :bigint
    add_index :shop_orders, :assigned_to_user_id
    add_foreign_key :shop_orders, :users, column: :assigned_to_user_id, on_delete: :nullify
  end
end

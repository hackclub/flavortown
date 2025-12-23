class AddDefaultAssignedUserToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :shop_items, :default_assigned_user, foreign_key: { to_table: :users, on_delete: :nullify }, index: true
  end
end

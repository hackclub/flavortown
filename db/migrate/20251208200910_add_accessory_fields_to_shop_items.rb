class AddAccessoryFieldsToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :buyable_by_self, :boolean, default: true
    add_column :shop_items, :attached_shop_item_ids, :bigint, array: true, default: []
  end
end

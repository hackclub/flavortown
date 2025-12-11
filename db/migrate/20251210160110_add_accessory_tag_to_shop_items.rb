class AddAccessoryTagToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :accessory_tag, :string
  end
end

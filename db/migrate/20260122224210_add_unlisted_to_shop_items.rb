class AddUnlistedToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :unlisted, :boolean, default: false
  end
end

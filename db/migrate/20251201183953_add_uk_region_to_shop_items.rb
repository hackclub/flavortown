class AddUkRegionToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :enabled_uk, :boolean
    add_column :shop_items, :price_offset_uk, :decimal, precision: 10, scale: 2
  end
end

class AddSourceRegionToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :source_region, :string
  end
end

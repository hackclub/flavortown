class AddAchievementSaleToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :achievement_sale_percentage, :integer
    add_column :shop_items, :achievement_sale_slugs, :string, array: true, default: []
  end
end

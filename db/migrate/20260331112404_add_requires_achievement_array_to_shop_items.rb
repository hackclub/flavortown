class AddRequiresAchievementArrayToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :requires_achievement_array, :text, array: true, default: []
  end
end

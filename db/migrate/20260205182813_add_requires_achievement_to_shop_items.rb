class AddRequiresAchievementToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :requires_achievement, :string
  end
end

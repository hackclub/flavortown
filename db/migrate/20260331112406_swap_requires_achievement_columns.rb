class SwapRequiresAchievementColumns < ActiveRecord::Migration[8.1]
  def up
    rename_column :shop_items, :requires_achievement, :requires_achievement_old
    rename_column :shop_items, :requires_achievement_array, :requires_achievement
    remove_column :shop_items, :requires_achievement_old
  end

  def down
    add_column :shop_items, :requires_achievement_old, :string
    rename_column :shop_items, :requires_achievement, :requires_achievement_array
    rename_column :shop_items, :requires_achievement_old, :requires_achievement
  end
end

class ChangeRequiresAchievementToArrayInShopItems < ActiveRecord::Migration[8.1]
  def change
    change_column :shop_items, :requires_achievement, :string, array: true, default: [], using: "COALESCE(string_to_array(requires_achievement, ','), '{}')"
  end
end

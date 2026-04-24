class ChangeRequiresAchievementToArrayInShopItems < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:shop_items, :requires_achievement_new)
      add_column :shop_items, :requires_achievement_new, :string, array: true, default: []
    end

    safety_assured do
      execute <<~SQL
        UPDATE shop_items
        SET requires_achievement_new = string_to_array(requires_achievement, ',')
        WHERE requires_achievement IS NOT NULL AND requires_achievement <> ''
      SQL
    end

    safety_assured do
      remove_column :shop_items, :requires_achievement
      rename_column :shop_items, :requires_achievement_new, :requires_achievement
    end
  end

  def down
    add_column :shop_items, :requires_achievement_old, :string

    safety_assured do
      execute <<~SQL
        UPDATE shop_items
        SET requires_achievement_old = array_to_string(requires_achievement, ',')
        WHERE requires_achievement IS NOT NULL
      SQL
    end

    safety_assured do
      remove_column :shop_items, :requires_achievement
      rename_column :shop_items, :requires_achievement_old, :requires_achievement
    end
  end
end

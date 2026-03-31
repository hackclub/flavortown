class BackfillRequiresAchievementArray < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    ShopItem.unscoped.in_batches(of: 1000) do |batch|
      batch.where.not(requires_achievement: [ nil, "" ]).update_all(
        "requires_achievement_array = string_to_array(requires_achievement, ',')"
      )
    end
  end

  def down
    ShopItem.unscoped.in_batches(of: 1000) do |batch|
      batch.update_all(
        "requires_achievement = array_to_string(requires_achievement_array, ',')"
      )
    end
  end
end

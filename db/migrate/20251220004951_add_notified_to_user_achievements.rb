# frozen_string_literal: true

class AddNotifiedToUserAchievements < ActiveRecord::Migration[8.1]
  def up
    add_column :user_achievements, :notified, :boolean, default: false, null: false
    User::Achievement.update_all(notified: true)
  end

  def down
    remove_column :user_achievements, :notified
  end
end

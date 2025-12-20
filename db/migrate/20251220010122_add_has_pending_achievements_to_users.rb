# frozen_string_literal: true

class AddHasPendingAchievementsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :has_pending_achievements, :boolean, default: false, null: false
  end
end

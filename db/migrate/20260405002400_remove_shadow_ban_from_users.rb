class RemoveShadowBanFromUsers < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_column :users, :shadow_banned, :boolean
      remove_column :users, :shadow_banned_at, :datetime
      remove_column :users, :shadow_banned_reason, :text
    end
  end
end

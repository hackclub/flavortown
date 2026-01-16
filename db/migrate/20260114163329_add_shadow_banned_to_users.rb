class AddShadowBannedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :shadow_banned, :boolean, default: false, null: false
    add_column :users, :shadow_banned_at, :datetime
    add_column :users, :shadow_banned_reason, :text
  end
end

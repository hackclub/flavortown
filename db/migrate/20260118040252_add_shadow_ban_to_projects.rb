class AddShadowBanToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :shadow_banned, :boolean, default: false, null: false
    add_column :projects, :shadow_banned_at, :datetime
    add_column :projects, :shadow_banned_reason, :text
    add_index :projects, :shadow_banned
  end
end

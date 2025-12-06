class AddBannedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :banned, :boolean, default: false, null: false
    add_column :users, :banned_at, :datetime
    add_column :users, :banned_reason, :text
  end
end

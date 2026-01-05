class AddDevlogNotificationOptOut < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :send_notifications_for_followed_devlogs, :boolean, default: true, null: false
  end
end

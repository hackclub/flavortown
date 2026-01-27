class AddCommentNotificationOptout < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :send_notifications_for_new_comments, :boolean, default: true, null: false
  end
end

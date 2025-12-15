class AddSlackBalanceNotificationsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :slack_balance_notifications, :boolean, default: false, null: false
  end
end

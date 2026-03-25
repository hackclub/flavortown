class AddMetricsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :flavortown_message_count_14d, :integer
    add_column :users, :flavortown_support_message_count_14d, :integer
    add_column :users, :projects_count, :integer
    add_column :users, :projects_shipped_count, :integer
    add_column :users, :slack_messages_updated_at, :datetime
    add_column :users, :metrics_synced_at, :datetime
  end
end

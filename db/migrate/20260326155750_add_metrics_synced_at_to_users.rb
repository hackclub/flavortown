class AddMetricsSyncedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :metrics_synced_at, :datetime
  end
end

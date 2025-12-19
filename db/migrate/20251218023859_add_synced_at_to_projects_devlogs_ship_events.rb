class AddSyncedAtToProjectsDevlogsShipEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :synced_at, :datetime
    add_column :post_devlogs, :synced_at, :datetime
    add_column :post_ship_events, :synced_at, :datetime
  end
end

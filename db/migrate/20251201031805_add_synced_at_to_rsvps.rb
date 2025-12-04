class AddSyncedAtToRsvps < ActiveRecord::Migration[8.1]
  def change
    add_column :rsvps, :synced_at, :datetime
  end
end

class AddSyncedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :synced_at, :datetime
  end
end

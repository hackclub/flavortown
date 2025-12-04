class AddDurationSecondsToPostDevlogs < ActiveRecord::Migration[8.1]
  def change
    add_column :post_devlogs, :duration_seconds, :integer
    add_column :post_devlogs, :hackatime_pulled_at, :datetime
    add_column :post_devlogs, :hackatime_projects_key_snapshot, :text
  end
end

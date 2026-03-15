class AddLapsePlaybackFieldsToPostDevlogs < ActiveRecord::Migration[8.1]
  def change
    add_column :post_devlogs, :lapse_playback_url, :string
    add_column :post_devlogs, :lapse_playback_url_refreshed_at, :datetime
  end
end

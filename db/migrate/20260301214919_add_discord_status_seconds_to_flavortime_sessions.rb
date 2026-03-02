class AddDiscordStatusSecondsToFlavortimeSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :flavortime_sessions, :discord_status_seconds, :integer, default: 0, null: false
  end
end

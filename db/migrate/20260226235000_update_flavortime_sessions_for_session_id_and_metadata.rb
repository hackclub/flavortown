class UpdateFlavortimeSessionsForSessionIdAndMetadata < ActiveRecord::Migration[8.1]
  def change
    rename_column :flavortime_sessions, :fingerprint, :session_id

    if index_name_exists?(:flavortime_sessions, "index_flavortime_sessions_on_fingerprint")
      rename_index :flavortime_sessions,
        "index_flavortime_sessions_on_fingerprint",
        "index_flavortime_sessions_on_session_id"
    end

    add_column :flavortime_sessions, :platform, :string
    add_column :flavortime_sessions, :app_version, :string
    add_column :flavortime_sessions, :ended_reason, :string
  end
end

class RefreshLapsePlaybackUrlJob < ApplicationJob
  queue_as :default

  def perform(devlog_id)
    devlog = Post::Devlog.find_by(id: devlog_id)
    return unless devlog
    return unless devlog.lapse_timelapse_id.present?
    return unless devlog.lapse_playback_url_stale?

    data = Lapse::Api::Timelapse.query(devlog.lapse_timelapse_id)
    timelapse = data&.dig("timelapse")

    if timelapse && timelapse["playbackUrl"].present?
      devlog.update_columns(
        lapse_playback_url: timelapse["playbackUrl"],
        lapse_playback_url_refreshed_at: Time.current
      )
    else
      devlog.update_columns(lapse_playback_url_refreshed_at: Time.current)
      Rails.logger.error "Failed to refresh Lapse playback URL for devlog #{devlog.id} (timelapse #{devlog.lapse_timelapse_id})"
    end
  end
end

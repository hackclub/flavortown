module Lapse
  # Legacy compatibility shim for already-enqueued jobs.
  # New devlog creation no longer enqueues this job — playback URLs are stored directly.
  class ProcessTimelapseJob < ApplicationJob
    queue_as :default

    def perform(devlog_id, timelapse_id, playback_url)
      Rails.logger.warn "Lapse::ProcessTimelapseJob: Legacy job executed for devlog #{devlog_id}. " \
        "Storing playback URL directly instead of downloading."

      devlog = Post::Devlog.find(devlog_id)

      devlog.update_columns(
        lapse_timelapse_id: timelapse_id,
        lapse_playback_url: playback_url,
        lapse_playback_url_refreshed_at: Time.current
      )
    rescue => e
      Rails.logger.error "Lapse::ProcessTimelapseJob: Error - #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      raise
    end
  end
end

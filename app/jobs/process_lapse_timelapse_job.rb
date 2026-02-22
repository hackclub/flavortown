class ProcessLapseTimelapseJob < ApplicationJob
  queue_as :default

  def perform(devlog_id, timelapse_id, playback_url)
    devlog = Post::Devlog.find(devlog_id)

    response = Faraday.get(playback_url)
    unless response.success?
      Rails.logger.error "ProcessLapseTimelapseJob: Failed to download timelapse #{timelapse_id} (HTTP #{response.status})"
      return
    end

    content_type = response.headers["content-type"] || "video/mp4"
    extension = Rack::Mime::MIME_TYPES.invert[content_type] || ".mp4"
    filename = "timelapse-#{timelapse_id}#{extension}"

    devlog.attachments.attach(
      io: StringIO.new(response.body),
      filename: filename,
      content_type: content_type
    )

    devlog.update!(lapse_video_processing: false)
  rescue => e
    Rails.logger.error "ProcessLapseTimelapseJob: Error - #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    raise
  end
end

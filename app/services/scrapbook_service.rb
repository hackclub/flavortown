class ScrapbookService
  SCRAPBOOK_CHANNEL_ID = "C01504DCLVD".freeze

  def self.populate_devlog_from_url(devlog_id)
    devlog = Post::Devlog.find_by(id: devlog_id)
    return unless devlog&.scrapbook_url.present?

    channel_id, message_ts = extract_slack_ids_from_url(devlog.scrapbook_url)
    return unless channel_id && message_ts
    return unless channel_id == SCRAPBOOK_CHANNEL_ID

    message = fetch_slack_message(channel_id, message_ts)
    return unless message

    body = message["text"]
    attach_slack_files(devlog, message, accepted_content_types: Post::Devlog::ACCEPTED_CONTENT_TYPES)

    devlog.reload
    devlog.update!(body: body) if body.present?

    notify_thread(message_ts, devlog.id)
  rescue StandardError => e
    Rails.logger.error("ScrapbookService failed for devlog #{devlog_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
    raise
  end

  def self.extract_slack_ids_from_url(url)
    match = url.match(%r{/archives/([A-Z0-9]+)/p(\d+)})
    return nil unless match

    channel_id = match[1]
    raw_ts = match[2]
    message_ts = "#{raw_ts[0..9]}.#{raw_ts[10..]}"

    [ channel_id, message_ts ]
  end

  # this does not work properly
  def self.message_exists?(channel_id, message_ts)
    fetch_slack_message(channel_id, message_ts).present?
  end

  class << self
    private

    def notify_thread(message_ts, devlog_id)
      return if message_ts.blank?

      SendSlackDmJob.perform_later(
        SCRAPBOOK_CHANNEL_ID,
        "This scrapbook post has been linked to a Flavortown devlog! :flavortown: " \
        "https://flavortown.hackclub.com/projects/#{devlog_id}",
        thread_ts: message_ts
      )
    end

    def fetch_slack_message(channel_id, message_ts)
      client = Slack::Web::Client.new(token: Rails.application.credentials.dig(:slack, :bot_token))

      response = client.conversations_history(
        channel: channel_id,
        oldest: message_ts,
        latest: message_ts,
        inclusive: true,
        limit: 1
      )

      if Rails.env.development?
        Rails.logger.debug("Slack API response for #{channel_id}/#{message_ts}: #{response.to_h}")
      end

      return nil unless response.ok && response.messages&.any?

      response.messages.first
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error("Failed to fetch Slack message: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
      nil
    rescue StandardError => e
      Rails.logger.error("Unexpected error fetching Slack message: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
      nil
    end

    def attach_slack_files(devlog, message, accepted_content_types:)
      files = message["files"] || []

      if Rails.env.development?
        Rails.logger.debug("Slack message files: #{files.inspect}")
      end

      if files.empty?
        Rails.logger.info("No files found in Slack message")
        return
      end

      token = Rails.application.credentials.dig(:slack, :bot_token)

      files.each do |file|
        Rails.logger.debug("Processing file: #{file['name']}, mimetype: #{file['mimetype']}, url: #{file['url_private_download']}") if Rails.env.development?

        unless file["url_private_download"].present?
          Rails.logger.warn("File #{file['name']} has no url_private_download - bot may need files:read scope")
          next
        end

        unless accepted_content_types.include?(file["mimetype"])
          Rails.logger.debug("Skipping file #{file['name']} - unsupported mimetype #{file['mimetype']}") if Rails.env.development?
          next
        end

        url = file["url_private_download"]
        Rails.logger.debug("Downloading file from: #{url}") if Rails.env.development?

        response = Faraday.get(url) do |req|
          req.headers["Authorization"] = "Bearer #{token}"
        end

        unless response.success?
          Rails.logger.error("Failed to download Slack file #{file['name']}: HTTP #{response.status}")
          next
        end

        Rails.logger.debug("Downloaded #{response.body.bytesize} bytes for #{file['name']}") if Rails.env.development?

        devlog.attachments.attach(
          io: StringIO.new(response.body),
          filename: file["name"],
          content_type: file["mimetype"]
        )
      rescue StandardError => e
        Rails.logger.error("Failed to download Slack file #{file['name']}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
      end
    end
  end
end

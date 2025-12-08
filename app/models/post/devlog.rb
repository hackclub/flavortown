# == Schema Information
#
# Table name: post_devlogs
#
#  id                              :bigint           not null, primary key
#  body                            :string
#  duration_seconds                :integer
#  hackatime_projects_key_snapshot :text
#  hackatime_pulled_at             :datetime
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#
class Post::Devlog < ApplicationRecord
  include Postable

  SCRAPBOOK_CHANNEL_ID = "C01504DCLVD".freeze

  ACCEPTED_CONTENT_TYPES = %w[
    image/jpeg
    image/png
    image/webp
    image/heic
    image/heif
    image/gif
    video/quicktime
    video/webm
    video/x-matroska].freeze


  validates :body, presence: true
  validates :scrapbook_url, uniqueness: { message: "has already been used for another devlog" }, allow_blank: true
  validate :validate_scrapbook_url

  before_validation :populate_from_scrapbook_url
  after_create :notify_scrapbook_thread

  # only for images – not for videos or gif!
  has_many_attached :attachments do |attachable|
    attachable.variant :large,
                       resize_to_fill: [ 1600, 900 ],
                       format: :webp,
                       preprocessed: true,
                       saver: { strip: true, quality: 75 }

    attachable.variant :medium,
                       resize_to_fill: [ 800, 800 ],
                       format: :webp,
                       preprocessed: false,
                       saver: { strip: true, quality: 75 }

    attachable.variant :thumb,
                       resize_to_fill: [ 400, 400 ],
                       format: :webp,
                       preprocessed: false,
                       saver: { strip: true, quality: 75 }
  end

  validates :attachments,
            content_type: { in: ACCEPTED_CONTENT_TYPES, spoofing_protection: true },
            size: { less_than: 50.megabytes, message: "is too large (max 50 MB)" },
            processable_file: true

  validate :at_least_one_attachment

  def at_least_one_attachment
    return if scrapbook_url.present?
    errors.add(:attachments, "must include at least one image or video") unless attachments.attached?
  end

  def validate_scrapbook_url
    return if scrapbook_url.blank?

    unless scrapbook_url.include?("hackclub") && scrapbook_url.include?("slack.com")
      errors.add(:scrapbook_url, "must be a Hack Club Slack URL")
      return
    end

    channel_id, message_ts = extract_slack_ids_from_url(scrapbook_url)
    unless channel_id && message_ts
      errors.add(:scrapbook_url, "is not a valid Slack message URL")
      return
    end

    unless channel_id == SCRAPBOOK_CHANNEL_ID
      errors.add(:scrapbook_url, "must be from the #scrapbook channel")
      return
    end

    unless @scrapbook_message_fetched
      errors.add(:scrapbook_url, "could not be verified - message not found")
    end
  end

  def populate_from_scrapbook_url
    return if scrapbook_url.blank?
    @scrapbook_message_fetched = false

    channel_id, message_ts = extract_slack_ids_from_url(scrapbook_url)
    return unless channel_id && message_ts
    return unless channel_id == SCRAPBOOK_CHANNEL_ID

    message = fetch_slack_message(channel_id, message_ts)
    return unless message

    @scrapbook_message_fetched = true
    self.body = message["text"]

    attach_slack_files(message)

    @scrapbook_message_ts = message_ts
  end

  def attach_slack_files(message)
    files = message["files"] || []

    if Rails.env.development?
      Rails.logger.debug("Slack message files: #{files.inspect}")
    end

    if files.empty?
      Rails.logger.info("No files found in Slack message")
      return
    end

    files.each do |file|
      Rails.logger.debug("Processing file: #{file['name']}, mimetype: #{file['mimetype']}, url: #{file['url_private_download']}") if Rails.env.development?

      unless file["url_private_download"].present?
        Rails.logger.warn("File #{file['name']} has no url_private_download - bot may need files:read scope")
        next
      end

      unless ACCEPTED_CONTENT_TYPES.include?(file["mimetype"])
        Rails.logger.debug("Skipping file #{file['name']} - unsupported mimetype #{file['mimetype']}") if Rails.env.development?
        next
      end

      download_and_attach_file(file)
    end
  end

  def download_and_attach_file(file)
    url = file["url_private_download"]
    token = Rails.application.credentials.dig(:slack, :bot_token)

    Rails.logger.debug("Downloading file from: #{url}") if Rails.env.development?

    response = Faraday.get(url) do |req|
      req.headers["Authorization"] = "Bearer #{token}"
    end

    unless response.success?
      Rails.logger.error("Failed to download Slack file #{file['name']}: HTTP #{response.status}")
      return
    end

    Rails.logger.debug("Downloaded #{response.body.bytesize} bytes for #{file['name']}") if Rails.env.development?

    attachments.attach(
      io: StringIO.new(response.body),
      filename: file["name"],
      content_type: file["mimetype"]
    )
  rescue StandardError => e
    Rails.logger.error("Failed to download Slack file #{file['name']}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
  end

  def notify_scrapbook_thread
    return if scrapbook_url.blank?
    return unless @scrapbook_message_ts

    SendSlackDmJob.perform_later(
      SCRAPBOOK_CHANNEL_ID,
      "This scrapbook post has been linked to a Flavortown devlog! :flavortown: https://flavortown.hackclub.com/projects/#{id}",
      thread_ts: @scrapbook_message_ts
    )
  end

  def extract_slack_ids_from_url(url)
    match = url.match(%r{/archives/([A-Z0-9]+)/p(\d+)})
    return nil unless match

    channel_id = match[1]
    raw_ts = match[2]
    message_ts = "#{raw_ts[0..9]}.#{raw_ts[10..]}"

    [ channel_id, message_ts ]
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

  def recalculate_seconds_coded
    post = posts.first
    return false unless post

    project = post.project
    user = post.user
    return false unless project && user

    prev_time = find_previous_devlog_time(project)

    return false unless project.hackatime_keys.present?

    fetch_and_update_duration(user, project, prev_time)
  rescue JSON::ParserError => e
    Rails.logger.error "JSON parse error in recalculate_seconds_coded for Devlog #{id}: #{e.message}"
    false
  rescue => e
    Rails.logger.error "Unexpected error in recalculate_seconds_coded for Devlog #{id}: #{e.message}"
    false
  end

  private

  def find_previous_devlog_time(project)
    Post.joins("INNER JOIN post_devlogs ON posts.postable_id::bigint = post_devlogs.id")
        .where(postable_type: "Post::Devlog", project_id: project.id)
        .where("posts.created_at < ?", posts.first.created_at)
        .order(created_at: :desc)
        .first&.created_at
  end

  def fetch_and_update_duration(user, project, prev_time)
    return false unless user.slack_id.present?

    hackatime_keys = project.hackatime_keys
    end_time = posts.first.created_at.utc

    # Build URL - first devlog gets all time since event start, subsequent get time since last devlog
    base_url = "https://hackatime.hackclub.com/api/v1/users/#{user.slack_id}/stats?features=projects"
    url = if prev_time.nil?
            "#{base_url}&start_date=2025-11-05"
    else
            "#{base_url}&start_date=#{prev_time.iso8601}&end_date=#{end_time.iso8601}"
    end

    headers = { "RACK_ATTACK_BYPASS" => ENV["HACKATIME_BYPASS_KEYS"] }.compact
    response = Faraday.get(url, nil, headers)

    if response.success?
      data = JSON.parse(response.body)
      projects_data = data.dig("data", "projects") || []

      # Sum up total_seconds for matching hackatime project keys
      seconds = projects_data
        .select { |p| hackatime_keys.include?(p["name"]) }
        .sum { |p| p["total_seconds"].to_i }

      Rails.logger.info "\tDevlog #{id} duration_seconds: #{seconds}"
      update!(
        duration_seconds: seconds,
        hackatime_pulled_at: Time.current,
        hackatime_projects_key_snapshot: hackatime_keys.join(",")
      )
      true
    else
      Rails.logger.error "Hackatime API failed for devlog #{id}: HTTP #{response.status} - #{response.body}"
      false
    end
  end
end

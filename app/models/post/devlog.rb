# == Schema Information
#
# Table name: post_devlogs
#
#  id                              :bigint           not null, primary key
#  body                            :string
#  comments_count                  :integer          default(0), not null
#  duration_seconds                :integer
#  hackatime_projects_key_snapshot :text
#  hackatime_pulled_at             :datetime
#  likes_count                     :integer          default(0), not null
#  scrapbook_url                   :string
#  synced_at                       :datetime
#  tutorial                        :boolean          default(FALSE), not null
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#
class Post::Devlog < ApplicationRecord
  include Postable

  ACCEPTED_CONTENT_TYPES = %w[
    image/jpeg
    image/png
    image/webp
    image/heic
    image/heif
    image/gif
    video/mp4
    video/quicktime
    video/webm
    video/x-matroska
  ].freeze

  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  # only for images – not for videos or gif!
  has_many_attached :attachments do |attachable|
    attachable.variant :large,
                       resize_to_limit: [ 1600, 900 ],
                       format: :webp,
                       preprocessed: true,
                       saver: { strip: true, quality: 75 }

    attachable.variant :medium,
                       resize_to_limit: [ 800, 800 ],
                       format: :webp,
                       preprocessed: false,
                       saver: { strip: true, quality: 75 }

    attachable.variant :thumb,
                       resize_to_limit: [ 400, 400 ],
                       format: :webp,
                       preprocessed: false,
                       saver: { strip: true, quality: 75 }
  end

  validates :attachments,
            content_type: { in: ACCEPTED_CONTENT_TYPES, spoofing_protection: true },
            size: { less_than: 50.megabytes, message: "is too large (max 50 MB)" },
            processable_file: true
  validate :at_least_one_attachment
  validates :duration_seconds,
            numericality: { greater_than_or_equal_to: 15.minutes },
            allow_nil: true
  validates :body, presence: true, length: { maximum: 2_000 }, unless: -> { scrapbook_url.present? }
  validates :scrapbook_url,
            uniqueness: { message: "has already been used for another devlog" },
            allow_blank: true,
            unless: -> { Rails.env.development? }
  validate :validate_scrapbook_url_format

  after_create :enqueue_scrapbook_population, if: -> { scrapbook_url.present? }
  after_create :notify_slack_channel

  def recalculate_seconds_coded
    return false unless post

    project = post.project
    user = post.user
    return false unless project && user

    prev_time = find_previous_devlog_time(project)

    return false unless project.hackatime_keys.present?

    fetch_and_update_duration(user, project, prev_time)
  rescue JSON::ParserError => e
    Rails.logger.error("JSON parse error in recalculate_seconds_coded for Devlog #{id}: #{e.message}")
    false
  rescue => e
    Rails.logger.error("Unexpected error in recalculate_seconds_coded for Devlog #{id}: #{e.message}")
    false
  end

  private

  def at_least_one_attachment
    return if scrapbook_url.present?

    errors.add(:attachments, "must include at least one image or video") unless attachments.attached?
  end

  def validate_scrapbook_url_format
    return if scrapbook_url.blank?

    unless scrapbook_url.include?("hackclub") && scrapbook_url.include?("slack.com")
      errors.add(:scrapbook_url, "must be a Hack Club Slack URL")
      return
    end

    channel_id, message_ts = ScrapbookService.extract_slack_ids_from_url(scrapbook_url)
    unless channel_id && message_ts
      errors.add(:scrapbook_url, "is not a valid Slack message URL")
      return
    end

    unless channel_id == ScrapbookService::SCRAPBOOK_CHANNEL_ID
      errors.add(:scrapbook_url, "must be from the #scrapbook channel")
      return
    end

    unless ScrapbookService.message_exists?(channel_id, message_ts)
      errors.add(:scrapbook_url, "could not be verified - message not found")
    end
  end

  def enqueue_scrapbook_population
    ScrapbookPopulateDevlogJob.perform_later(id)
  end

  def notify_slack_channel
    PostCreationToSlackJob.perform_later(self)
  end

  def find_previous_devlog_time(project)
    Post.joins("INNER JOIN post_devlogs ON posts.postable_id::bigint = post_devlogs.id")
        .where(postable_type: "Post::Devlog", project_id: project.id)
        .where("posts.created_at < ?", post.created_at)
        .order(created_at: :desc)
        .first&.created_at
  end

  def fetch_and_update_duration(user, project, prev_time)
    return false unless user.hackatime_identity

    hackatime_keys = project.hackatime_keys
    end_time = post.created_at.utc

    result = if prev_time.nil?
      HackatimeService.fetch_stats(user.hackatime_identity.uid)
    else
      HackatimeService.fetch_stats(
        user.hackatime_identity.uid,
        start_date: prev_time.iso8601,
        end_date: end_time.iso8601
      )
    end

    return false unless result

    seconds = hackatime_keys.sum { |key| result[:projects][key].to_i }

    Rails.logger.info("\tDevlog #{id} duration_seconds: #{seconds}")
    update!(
      duration_seconds: seconds,
      hackatime_pulled_at: Time.current,
      hackatime_projects_key_snapshot: hackatime_keys.join(",")
    )
    true
  end
end

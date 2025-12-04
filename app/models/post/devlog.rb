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

    project_keys = project.hackatime_keys.join(",")
    encoded_project_keys = URI.encode_www_form_component(project_keys)
    end_time = posts.first.created_at.utc

    # For first devlog (no prev_time), get total time without date filter
    # Then subtract any already-logged time from other devlogs
    url = if prev_time.nil?
            "https://hackatime.hackclub.com/api/v1/users/#{user.slack_id}/stats?" \
            "filter_by_project=#{encoded_project_keys}&" \
            "features=projects&total_seconds=true"
          else
            "https://hackatime.hackclub.com/api/v1/users/#{user.slack_id}/stats?" \
            "filter_by_project=#{encoded_project_keys}&" \
            "start_date=#{prev_time.iso8601}&" \
            "end_date=#{end_time.iso8601}&" \
            "features=projects&total_seconds=true"
          end

    headers = { "RACK_ATTACK_BYPASS" => ENV["HACKATIME_BYPASS_KEYS"] }.compact
    response = Faraday.get(url, nil, headers)

    if response.success?
      data = JSON.parse(response.body)
      seconds = data.dig("total_seconds")

      Rails.logger.info "\tDevlog #{id} duration_seconds: #{seconds}"
      update!(
        duration_seconds: seconds,
        hackatime_pulled_at: Time.current,
        hackatime_projects_key_snapshot: project.hackatime_keys.join(",")
      )
      true
    else
      Rails.logger.error "Hackatime API failed for devlog #{id}: HTTP #{response.status} - #{response.body}"
      false
    end
  end
end

module ExtensionUsageTrackable
  extend ActiveSupport::Concern

  included do
    after_action :track_extension_usage
  end

  private

  def track_extension_usage
    return unless current_user
    return unless redis_available?

    project_ids = extract_extension_project_ids
    return if project_ids.empty?

    timestamp = Time.current.iso8601

    payloads = project_ids.map do |project_id|
      { project_id: project_id, user_id: current_user.id, recorded_at: timestamp }.to_json
    end

    Rails.cache.redis.with do |redis|
      redis.lpush(FlushExtensionUsageJob::BUFFER_KEY, payloads)
    end
  rescue StandardError => e
    Rails.logger.warn("Extension usage tracking failed: #{e.class}: #{e.message}")
  end

  def redis_available?
    Rails.cache.respond_to?(:redis) && Rails.cache.redis.present?
  end

  def extract_extension_project_ids
    project_ids = []

    request.headers.each do |key, value|
      if key.to_s.match?(/\AHTTP_X_FLAVORTOWN_EXT_(\d+)\z/i)
        project_id = key.to_s.match(/\AHTTP_X_FLAVORTOWN_EXT_(\d+)\z/i)[1].to_i
        project_ids << project_id if project_id > 0
      end
    end

    project_ids.uniq
  end
end

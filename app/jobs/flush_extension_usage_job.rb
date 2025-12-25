class FlushExtensionUsageJob < ApplicationJob
  BUFFER_KEY = "flavortown:extension_usage_buffer"

  queue_as :default

  def perform
    return unless redis_available?

    records = []
    batch_size = 1000

    while (raw = Rails.cache.redis.lpop(BUFFER_KEY))
      data = JSON.parse(raw)
      records << {
        project_id: data["project_id"],
        user_id: data["user_id"],
        recorded_at: data["recorded_at"],
        created_at: Time.current,
        updated_at: Time.current
      }

      if records.size >= batch_size
        insert_batch(records)
        records = []
      end
    end

    insert_batch(records) if records.any?
  end

  private

  def insert_batch(records)
    return if records.empty?

    project_ids = records.map { |r| r[:project_id] }.uniq
    valid_project_ids = Project.where(id: project_ids).pluck(:id).to_set

    valid_records = records.select { |r| valid_project_ids.include?(r[:project_id]) }
    ExtensionUsage.insert_all(valid_records) if valid_records.any?
  end

  def redis_available?
    Rails.cache.respond_to?(:redis) && Rails.cache.redis.present?
  end
end

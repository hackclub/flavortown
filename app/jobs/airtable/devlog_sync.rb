class Airtable::DevlogSync < ApplicationJob
  queue_as :literally_whenever

  def self.perform_later(*args)
    return if SolidQueue::Job.where(class_name: name, finished_at: nil).exists?

    super
  end

  def perform
    table = Norairrecord.table(
      Rails.application.credentials&.airtable&.api_key || ENV["AIRTABLE_API_KEY"],
      Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"],
      "_devlogs"
    )

    records = devlogs_to_sync.map do |devlog|
      post = devlog.posts.first
      table.new({
        "body" => devlog.body,
        "duration_seconds" => devlog.duration_seconds,
        "likes_count" => devlog.likes_count,
        "comments_count" => devlog.comments_count,
        "scrapbook_url" => devlog.scrapbook_url,
        "project_id" => post&.project_id,
        "user_id" => post&.user_id,
        "created_at" => devlog.created_at,
        "synced_at" => Time.now,
        "flavor_id" => devlog.id
      })
    end

    table.batch_upsert(records, "flavor_id")
  ensure
    devlogs_to_sync.update_all(synced_at: Time.now)
  end

  private

  def devlogs_to_sync
    @devlogs_to_sync ||= Post::Devlog.includes(:posts).order("synced_at ASC NULLS FIRST").limit(10)
  end
end

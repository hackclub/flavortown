class Airtable::ShipEventSync < ApplicationJob
  queue_as :literally_whenever

  def self.perform_later(*args)
    return if SolidQueue::Job.where(class_name: name, finished_at: nil).exists?

    super
  end

  def perform
    table = Norairrecord.table(
      Rails.application.credentials&.airtable&.api_key || ENV["AIRTABLE_API_KEY"],
      Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"],
      "_ship_events"
    )

    records = ship_events_to_sync.map do |ship_event|
      post = ship_event.posts.first
      table.new({
        "body" => ship_event.body,
        "certification_status" => ship_event.certification_status,
        "hours" => ship_event.hours,
        "multiplier" => ship_event.multiplier,
        "payout" => ship_event.payout,
        "votes_count" => ship_event.votes_count,
        "project_id" => post&.project_id,
        "user_id" => post&.user_id,
        "created_at" => ship_event.created_at,
        "synced_at" => Time.now,
        "flavor_id" => ship_event.id
      })
    end

    table.batch_upsert(records, "flavor_id")
  ensure
    ship_events_to_sync.update_all(synced_at: Time.now)
  end

  private

  def ship_events_to_sync
    @ship_events_to_sync ||= Post::ShipEvent.includes(:posts).order("synced_at ASC NULLS FIRST").limit(10)
  end
end

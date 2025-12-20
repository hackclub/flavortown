class Airtable::ShipEventSyncJob < Airtable::BaseSyncJob
  def table_name = "_ship_events"

  def records = Post::ShipEvent.includes(:posts)

  def field_mapping(ship_event)
    post = ship_event.posts.first
    {
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
    }
  end
end

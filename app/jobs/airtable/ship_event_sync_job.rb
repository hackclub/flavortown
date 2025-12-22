class Airtable::ShipEventSyncJob < Airtable::BaseSyncJob
  def table_name = "_ship_events"

  def records = Post::ShipEvent.includes(:post)

  def field_mapping(ship_event)
    post = ship_event.post
    {
      "body" => ship_event.body,
      "certification_status" => ship_event.certification_status,
      "hours" => ship_event.hours,
      "multiplier" => ship_event.multiplier,
      "payout" => ship_event.payout,
      "votes_count" => ship_event.votes_count,
      "project_id" => post&.project_id&.to_s,
      "user_id" => post&.user_id&.to_s,
      "created_at" => ship_event.created_at,
      "synced_at" => Time.now,
      "flavor_id" => ship_event.id.to_s
    }
  end
end

class Airtable::RsvpSyncJob < Airtable::BaseSyncJob
  def table_name = "_rsvps"

  def records = Rsvp.all

  def primary_key_field = "email"

  def null_sync_limit = 100

  def field_mapping(rsvp)
    {
      "email" => rsvp.email,
      "ip" => rsvp&.ip_address,
      "user_agent" => rsvp&.user_agent,
      "ref" => rsvp&.ref,
      "created_at" => rsvp.created_at,
      "synced_at" => Time.now,
      "flavor_id" => rsvp.id.to_s
    }
  end
end

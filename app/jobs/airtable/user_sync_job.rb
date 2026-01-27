class Airtable::UserSyncJob < Airtable::BaseSyncJob
  def table_name = "_users"

  # Only sync users with emails to avoid duplicate nil key issues in Airtable
  def records = User.where.not(email: [ nil, "" ])

  def primary_key_field = "email"

  def field_mapping(user)
    funnel_events = FunnelEvent.where(user_id: user.id)
                               .or(FunnelEvent.where(email: user.email&.downcase))
                               .order(:created_at)
    last_event = funnel_events.last
    address = user.addresses.first

    fields = {
      "first_name" => user.first_name,
      "last_name" => user.last_name,
      "email" => user.email,
      "slack_id" => user.slack_id,
      "avatar_url" => "https://cachet.dunkirk.sh/users/#{user.slack_id}/r",
      "has_commented" => user.has_commented?,
      "has_some_role_of_access" => user.roles.any?,
      "hours" => user.all_time_coding_seconds&.fdiv(3600),
      "verification_status" => user.verification_status.to_s,
      "created_at" => user.created_at,
      "synced_at" => Time.now,
      "is_banned" => user.banned,
      "flavor_id" => user.id.to_s,
      "ref" => user.ref,
      "last_funnel_event" => last_event&.event_name,
      "last_funnel_event_at" => last_event&.created_at,
      "funnel_events" => funnel_events.pluck(:event_name).uniq.join(",")
    }

    if address.present?
      fields.merge!(
        "address_line_1" => address["address_line_1"],
        "address_line_2" => address["address_line_2"],
        "address_city" => address["city"],
        "address_state" => address["state_province"],
        "address_postal_code" => address["postal_code"],
        "address_country" => address["country"]
      )
    end

    fields
  end
end

class Airtable::UserSyncJob < Airtable::BaseSyncJob
  def table_name = "_users"

  def records = User.all

  def primary_key_field = "slack_id"

  def field_mapping(user)
    {
      "first_name" => user.first_name,
      "last_name" => user.last_name,
      "email" => user.email,
      "slack_id" => user.slack_id,
      "avatar_url" => "http://cachet.dunkirk.sh/users/#{user.slack_id}/r",
      "has_commented" => user.has_commented?,
      "has_some_role_of_access" => user.roles.any?,
      "hours" => user.all_time_coding_seconds&.fdiv(3600),
      "verification_status" => user.verification_status.to_s,
      "created_at" => user.created_at,
      "synced_at" => Time.now,
      "is_banned" => user.banned,
      "flavor_id" => user.id.to_s,
      "ref" => user.ref
    }
  end
end

class Airtable::PreSignupLeadSyncJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    pre_signup_emails = FunnelEvent.pre_signup
                                   .where.not(email: User.select(:email))
                                   .distinct
                                   .pluck(:email)

    return if pre_signup_emails.empty?

    airtable_records = pre_signup_emails.map do |email|
      table.new(field_mapping(email))
    end

    table.batch_upsert(airtable_records, "email")
  end

  private

  def field_mapping(email)
    funnel_events = FunnelEvent.where(email: email).order(:created_at)
    last_event = funnel_events.last

    {
      "email" => email,
      "last_funnel_event" => last_event&.event_name,
      "last_funnel_event_at" => last_event&.created_at,
      "funnel_events" => funnel_events.pluck(:event_name).uniq.join(","),
      "synced_at" => Time.now
    }
  end

  def table
    @table ||= Norairrecord.table(
      Rails.application.credentials&.airtable&.api_key || ENV["AIRTABLE_API_KEY"],
      Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"],
      "_users"
    )
  end
end

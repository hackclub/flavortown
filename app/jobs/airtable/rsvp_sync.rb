class Airtable::RsvpSync < ApplicationJob
    queue_as :literally_whenever
    # Prevent multiple jobs from being enqueued
    def self.perform_later(*args)
      return if SolidQueue::Job.where(class_name: name, finished_at: nil).exists?

      super
    end
    def perform
      table = Norairrecord.table(
      Rails.application.credentials.airtable.api_key || ENV["AIRTABLE_API_KEY"],
      Rails.application.credentials.airtable.base_id || ENV["AIRTABLE_BASE_ID"],
      "_rsvps"
      )
     records = rsvps_to_sync.map do |rsvp|
        table.new({
        "email" => rsvp.email,
        "ip" => rsvp.ip,
        "user_agent" => rsvp.user_agent,
        # "ref" => rsvp.ref,
        "created_at" => rsvp.created_at,
        "synced_at" => Time.now,
        # "som_id" => rsvp.id
        })
      end

      table.batch_upsert(records, "slack_id")
    ensure
        rsvps_to_sync.update_all(synced_at: Time.now)
    end
      private

    
  def rsvps_to_sync
    @rsvps_to_sync ||= Rsvp.order("synced_at ASC NULLS FIRST").limit(10)
  end
end

class Airtable::UserSync < ApplicationJob
    queue_as :literally_whenever
    # Prevent multiple jobs from being enqueued
    def self.perform_later(*args)
      return if SolidQueue::Job.where(class_name: name, finished_at: nil).exists?

      super
    end
    def perform
      table = Norairrecord.table(
      Rails.application.credentials&.airtable&.api_key || ENV["AIRTABLE_API_KEY"],
      Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"],
      "_users"
      )
     records = users_to_sync.map do |user|
        table.new({
          "first_name" => user.first_name,
          "last_name" => user.last_name,
          "email" => user.email,
          "slack_id" => user.slack_id,
          "avatar_url" => "http://cachet.dunkirk.sh/users/#{user.slack_id}/r",
          "has_commented" => user.has_commented,
          "has_some_role_of_access" => user.roles.any?,
          "hours" => user.all_time_coding_seconds&.fdiv(3600),
          "verification_status" => user.verification_status.to_s,
          "created_at" => user.created_at,
          "synced_at" => Time.now,
          "is_banned" => user.banned,
          "flavor_id" => user.id
        })
      end

      table.batch_upsert(records, "slack_id")
    ensure
        users_to_sync.update_all(synced_at: Time.now)
    end
      private

      def users_to_sync
        @users_to_sync ||= User.order("synced_at ASC NULLS FIRST").limit(10)
      end
end

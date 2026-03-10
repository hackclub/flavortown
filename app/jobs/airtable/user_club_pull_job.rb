class Airtable::UserClubPullJob < ApplicationJob
  queue_as :literally_whenever
  retry_on Norairrecord::Error, wait: :polynomially_longer, attempts: 3

  def perform
    User.where.not(email: [ nil, "" ]).find_each do |user|
      record = table.all(filter: "{email} = '#{user.email}'").first
      next unless record

      updates = {}
      updates[:airtable_record_id] = record.id if user.airtable_record_id != record.id

      club_name = record["club_name (from club)"]
      club_name = club_name.first if club_name.is_a?(Array)
      updates[:club_name] = club_name if user.club_name != club_name

      club_link = record["club_link"]
      updates[:club_link] = club_link if user.club_link != club_link

      user.update_columns(updates) if updates.any?
    end
  end

  private

  def table
    @table ||= Norairrecord.table(
      Rails.application.credentials&.airtable&.api_key || ENV["AIRTABLE_API_KEY"],
      Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"],
      "_users"
    )
  end
end

# unfinished :pf:
class SyncDataToAirtable < ApplicationJob
  queue_as :default

  BASE_ID = "appeQS7itMURezTwu"
  USER_TABLE_ID = "tblPGFASW87UmyWfM"

  # Use Airtable field IDs (robust to column renames)
  USER_FIELD_IDS = {
    slack_id: "fld4RrfNXqLu3EUta",
    full_name: "fldjT3LU9lVTzNmIU",
    email: "fldOc2HYj2Cgtia9J",
  }

  def perform
    Rails.logger.info "[SyncUsersToAirtableJob] Starting"

    unless ENV["AIRTABLE_KEY"].present?
      Rails.logger.error "[SyncUsersToAirtableJob] Missing AIRTABLE_KEY"
      return
    end

    # Cache existing Airtable records by Slack ID for upsert behavior
    existing_by_slack_id = fetch_existing_records_indexed_by_slack_id

    to_create = []
    to_update = []

    User.find_each(batch_size: 200) do |user|
      fields = build_fields_for_user(user)
      slack_id_value = fields[USER_FIELD_IDS[:slack_id]]
      next if slack_id_value.blank?

      if (existing = existing_by_slack_id[slack_id_value])
        # Prepare update payload using record id and fields
        to_update << existing.tap { |rec| fields.each { |k, v| rec[k] = v } }
      else
        to_create << fields
      end
    rescue => e
      Rails.logger.error "[SyncUsersToAirtableJob] Failed to prepare user #{user.id}: #{e.message}"
    end

    # Batch operations to reduce API calls; process in small slices with rate-limit backoff
    to_create.each_slice(10) do |slice|
      with_rate_limit_retry(operation: "batch_create", count: slice.size) do
        records = slice.map { |fields| table.new(fields) }
        table.batch_create(records)
      end
      # stay under 5 rps cap
      sleep 0.25
    end

    to_update.each_slice(10) do |slice|
      with_rate_limit_retry(operation: "batch_update", count: slice.size) do
        table.batch_update(slice)
      end
      # stay under 5 rps cap
      sleep 0.25
    end

    Rails.logger.info "[SyncUsersToAirtableJob] Completed"
  rescue => e
    Rails.logger.error "[SyncUsersToAirtableJob] Job error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  private

  def table
    @table ||= Norairrecord.table(
      ENV["UNIFIED_DB_INTEGRATION_AIRTABLE_KEY"],
      BASE_ID,
      USER_TABLE_ID
    )
  end

  def fetch_existing_records_indexed_by_slack_id
    index = {}
    begin
      # Fetch all records in batches (Norairrecord handles pagination internally on .all)
    records = with_rate_limit_retry(operation: "fetch_all") { table.all }
      records = with_rate_limit_retry(operation: "fetch_all") { table.all }
      records.each do |rec|
      slack_id_value = rec.fields[USER_FIELD_IDS[:slack_id]]
        index[slack_id_value] = rec if slack_id_value.present?
      end
    rescue => e
      Rails.logger.error "[SyncUsersToAirtableJob] Failed to fetch existing records: #{e.message}"
    end
    index
  end

  def build_fields_for_user(user)
    helpers = ApplicationController.helpers
    address = user.address

    fields = {}
    fields[FIELD_IDS[:slack_id]] = user.slack_id
    fields[FIELD_IDS[:slack_display_name]] = user.display_name.presence || user.name
    fields[FIELD_IDS[:email]] = user.email
    fields[FIELD_IDS[:status]] = user.status

    if address
      fields[FIELD_IDS[:first_name]] = address.first_name
      fields[FIELD_IDS[:last_name]] = address.last_name
      fields[FIELD_IDS[:shipping_name]] = address.shipping_name
      fields[FIELD_IDS[:birthday]] = address.birthday&.iso8601
      fields[FIELD_IDS[:line_one]] = address.line_one
      fields[FIELD_IDS[:line_two]] = address.line_two
      fields[FIELD_IDS[:city]] = address.city
      fields[FIELD_IDS[:postcode]] = address.postcode
      fields[FIELD_IDS[:state]] = address.state
      fields[FIELD_IDS[:country]] = address.human_country || address.country
    else
      # Ensure keys exist even if address is missing
      [ :first_name, :last_name, :shipping_name, :birthday, :line_one, :line_two, :city, :postcode, :state, :country ].each do |key|
        fields[FIELD_IDS[key]] = nil
      end
    end

    fields
  end

  def with_rate_limit_retry(max_attempts: 6, base_sleep: 1.0, jitter: 0.5, operation: nil, count: nil)
    attempt = 0
    begin
      attempt += 1
      return yield
    rescue => e
      if rate_limit_error?(e) && attempt < max_attempts
        wait = rate_limit_wait_seconds(e)
        if wait
          Rails.logger.warn "[SyncUsersToAirtableJob] 429 rate limit on #{operation || 'operation'}#{" (#{count})" if count}: sleeping #{wait}s"
          sleep wait
        else
          sleep_seconds = (base_sleep * (2 ** (attempt - 1))) + rand * jitter
          Rails.logger.warn "[SyncUsersToAirtableJob] Throttled on #{operation || 'operation'}#{" (#{count})" if count}: attempt #{attempt}/#{max_attempts}, sleeping #{sleep_seconds.round(2)}s"
          sleep sleep_seconds
        end
        retry
      end
      Rails.logger.error "[SyncUsersToAirtableJob] #{operation || 'operation'} failed: #{e.message}"
      raise e
    end
  end

  def rate_limit_error?(error)
    message = error.message.to_s
    code = (error.respond_to?(:code) ? error.code.to_s : nil)
    message.match?(/rate limit|too many requests|429/i) || code == "429"
  end

  def rate_limit_wait_seconds(error)
    code = (error.respond_to?(:code) ? error.code.to_s : nil)
    return 30 if code == "429" || error.message.to_s.match?(/\b429\b/)
    nil
  end
end


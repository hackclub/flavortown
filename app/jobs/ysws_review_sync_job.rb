class YswsReviewSyncJob < ApplicationJob
  queue_as :default

  def self.perform_later(*args)
    return if SolidQueue::Job.where(class_name: name, finished_at: nil).exists?

    super
  end

  def perform
    hours = YswsReviewService.hours_since_last_sync
    Rails.logger.info "[YswsReviewSyncJob] Fetching reviews from last #{hours} hours"

    reviews_response = YswsReviewService.fetch_reviews(hours: hours, status: "done")
    reviews = reviews_response["reviews"] || []

    Rails.logger.info "[YswsReviewSyncJob] Found #{reviews.count} reviews to sync"

    reviews.each do |review_summary|
      process_review(review_summary["id"])
    rescue StandardError => e
      Rails.logger.error "[YswsReviewSyncJob] Error processing review #{review_summary['id']}: #{e.message}"
      Sentry.capture_exception(e, extra: { review_id: review_summary["id"] })
    end

    YswsReviewService.update_last_synced_at!
  end

  private

  def process_review(review_id)
    current_review = YswsReviewService.fetch_review(review_id)
    ship_cert = current_review["shipCert"] || {}
    slack_id = ship_cert["ftSlackID"]

    return if slack_id.blank?

    user = User.find_by(slack_id: slack_id)
    return if user.nil?

    user_pii = extract_user_pii(user)

    create_airtable_record(current_review, user_pii)
  end

  def extract_user_pii(user)
    addresses = user.addresses

    {
      slack_id: user.slack_id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      display_name: user.display_name,
      addresses: addresses
    }
  end

  def create_airtable_record(review, user_pii)
    table.create(build_record_fields(review, user_pii))
  end

  def build_record_fields(review, user_pii)
    ship_cert = review["shipCert"] || {}
    primary_address = user_pii[:addresses]&.first || {}

    {
      "review_id" => review["id"].to_s,
      "slack_id" => user_pii[:slack_id],
      "email" => user_pii[:email],
      "first_name" => user_pii[:first_name],
      "last_name" => user_pii[:last_name],
      "display_name" => user_pii[:display_name],
      "address_line_1" => primary_address["line1"],
      "address_line_2" => primary_address["line2"],
      "city" => primary_address["city"],
      "state" => primary_address["state"],
      "postal_code" => primary_address["postalCode"],
      "country" => primary_address["country"],
      "ship_cert_id" => ship_cert["id"].to_s,
      "status" => review["status"],
      "synced_at" => Time.current.iso8601
    }
  end

  def table
    @table ||= Norairrecord.table(
      airtable_api_key,
      airtable_base_id,
      table_name
    )
  end

  def table_name
    Rails.application.credentials.dig(:ysws_review, :airtable_table_name) ||
      ENV["YSWS_REVIEW_AIRTABLE_TABLE"] ||
      "YSWS Reviews"
  end

  def airtable_api_key
    Rails.application.credentials.dig(:ysws_review, :airtable_api_key) ||
      Rails.application.credentials&.airtable&.api_key ||
      ENV["AIRTABLE_API_KEY"]
  end

  def airtable_base_id
    Rails.application.credentials.dig(:ysws_review, :airtable_base_id) ||
      ENV["YSWS_REVIEW_AIRTABLE_BASE_ID"]
  end
end

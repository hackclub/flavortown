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

    approved_reviews = reviews.select { |r| r["totalTime"].to_i > 0 }
    Rails.logger.info "[YswsReviewSyncJob] #{approved_reviews.count} approved reviews (filtered out #{reviews.count - approved_reviews.count} rejected)"

    approved_reviews.each do |review_summary|
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
    approved_orders = user.shop_orders.where(aasm_state: "fulfilled").includes(:shop_item)

    create_airtable_record(current_review, user_pii, approved_orders)
  end

  def extract_user_pii(user)
    addresses = user.addresses

    {
      slack_id: user.slack_id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      display_name: user.display_name,
      addresses: addresses,
      birthday: user.birthday
    }
  end

  def create_airtable_record(review, user_pii, approved_orders)
    table.create(build_record_fields(review, user_pii, approved_orders))
  end

  def build_record_fields(review, user_pii, approved_orders)
    ship_cert = review["shipCert"] || {}
    primary_address = user_pii[:addresses]&.first || {}
    devlogs = review["devlogs"] || []

    {
      "review_id" => review["id"].to_s,
      "slack_id" => user_pii[:slack_id],
      "Email" => user_pii[:email],
      "First Name" => user_pii[:first_name],
      "Last Name" => user_pii[:last_name],
      "display_name" => user_pii[:display_name],
      "Address (Line 1)" => primary_address["line1"],
      "Address (Line 2)" => primary_address["line2"],
      "City" => primary_address["city"],
      "State / Province" => primary_address["state"],
      "ZIP / Postal Code" => primary_address["postalCode"],
      "Country" => primary_address["country"],
      "Birthday" => user_pii[:birthday],
      "ship_cert_id" => ship_cert["id"].to_s,
      "status" => review["status"],
      "synced_at" => Time.current.iso8601,
      "reviewer" => review.dig("reviewer", "username"),
      "Code URL" => ship_cert["repoUrl"],
      "Playable URL" => ship_cert["demoUrl"],
      "project_readme" => ship_cert["readmeUrl"],
      "Screenshot" => ship_cert["proofVideoUrl"],
      "Description" => ship_cert["description"],
      "Optional - Override Hours Spent" => calculate_total_approved_minutes(devlogs),
      "Optional - Override Hours Spent Justification" => build_justification(review, devlogs, approved_orders)
    }
  end

  def calculate_total_approved_minutes(devlogs)
    return nil if devlogs.empty?

    devlogs.sum { |d| d["approvedMinutes"].to_i }
  end

  def build_justification(review, devlogs, approved_orders)
    return nil if devlogs.empty?

    ship_cert = review["shipCert"] || {}
    reviewer_username = review.dig("reviewer", "username") || "Unknown"
    ship_certifier = ship_cert["certifierName"] || "a ship certifier"
    project_id = ship_cert["ftProjectId"]
    review_id = review["id"]
    ship_cert_id = ship_cert["id"]

    total_original_minutes = devlogs.sum { |d| d["originalMinutes"].to_i }
    total_hours = total_original_minutes / 60
    original_time_remaining_minutes = total_original_minutes % 60
    original_time_formatted = total_hours > 0 ? "#{total_hours}h #{original_time_remaining_minutes}min" : "#{original_time_remaining_minutes}min"

    total_approved_minutes = devlogs.sum { |d| d["approvedMinutes"].to_i }
    approved_hours = total_approved_minutes / 60
    approved_time_remaining_minutes = total_approved_minutes % 60
    approved_time_formatted = approved_hours > 0 ? "#{approved_hours}h #{approved_time_remaining_minutes}min" : "#{approved_time_remaining_minutes}min"

    selected_devlogs = devlogs.count > 4 ? [ devlogs.first ] + devlogs.last(3) : devlogs
    devlog_list = selected_devlogs.map do |d|
      title = d["title"].presence || "Untitled Devlog"
      approved = d["approvedMinutes"].to_i
      "#{title}: #{approved} mins"
    end.join("\n")
    devlog_list += "\nand #{devlogs.count - 4} more devlogs." if devlogs.count > 4

    orders_section = build_orders_section(approved_orders)

    <<~JUSTIFICATION
      The user logged #{original_time_formatted} on hackatime. (#{total_original_minutes == total_approved_minutes ? "" : "This was adjusted to #{approved_time_formatted} after review."})

      In this time they wrote #{devlogs.count} devlogs.

      This project was initially ship certified by #{ship_certifier}.

      Following this it was YSWS reviewed by #{reviewer_username}.

      #{reviewer_username} approved:

      #{devlog_list}
      ====================================================
      You can checkout the Full YSWS Review + devlogs at https://review.hackclub.com/admin/ysws_reviews/#{review_id}

      You can checkout the Ship Cert at https://review.hackclub.com/admin/ship_certifications/#{ship_cert_id}/edit
      ====================================================
      #{orders_section}
    JUSTIFICATION
  end

  def build_orders_section(approved_orders)
    return "" if approved_orders.empty?

    orders_list = approved_orders.last(2).map do |order|
      item_name = order.shop_item.name
      fulfilled_by = order.fulfilled_by.presence || "Unknown"
      fulfilled_at = order.fulfilled_at&.strftime("%Y-%m-%d") || "Unknown date"
      "#{item_name} (x#{order.quantity}) - approved by #{fulfilled_by} on #{fulfilled_at}"
    end.join("\n")

    <<~ORDERS

      This was fraud checked #{approved_orders.count} time(s).

      #{orders_list}
    ORDERS
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
      "YSWS Project Submission"
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

class YswsReviewSyncJob < ApplicationJob
  include Rails.application.routes.url_helpers

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
    devlogs = current_review["devlogs"] || []
    total_approved_minutes = calculate_total_approved_minutes(devlogs) || 0

    if total_approved_minutes < 5
      Rails.logger.info "[YswsReviewSyncJob] Rejecting review #{review_id}: only #{total_approved_minutes} approved minutes (< 5)"
      return
    end

    ship_cert = current_review["shipCert"] || {}
    code_url = ship_cert["repoUrl"]
    ft_project_id = ship_cert["ftProjectId"]

    if project_has_active_reports?(ft_project_id)
      Rails.logger.info "[YswsReviewSyncJob] Skipping review #{review_id}: project has pending or reviewed reports"
      return
    end

    # Check if project already exists in unified database (duplicate check)
    if code_url.present? && project_exists_in_unified_db?(code_url)
      Rails.logger.info "[YswsReviewSyncJob] Skipping review #{review_id}: project already exists in unified database"
      return
    end

    slack_id = ship_cert["ftSlackId"]

    return if slack_id.blank?

    user = User.find_by(slack_id: slack_id)
    return if user.nil?

    approved_orders = user.shop_orders.where(aasm_state: "fulfilled").where.not(fulfilled_by: "System").includes(:shop_item)

    if approved_orders.none?
      Rails.logger.info "[YswsReviewSyncJob] Skipping review #{review_id}: user #{slack_id} has no manually fulfilled orders"
      return
    end

    user_pii = extract_user_pii(user)

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
    ship_cert = review["shipCert"] || {}
    ship_cert_id = ship_cert["id"].to_s
    fields = build_record_fields(review, user_pii, approved_orders)

    Rails.logger.info "[YswsReviewSyncJob] Upserting Airtable record for ship_cert_id #{ship_cert_id}"
    table.upsert(fields, "ship_cert_id")
  end

  def build_record_fields(review, user_pii, approved_orders)
    ship_cert = review["shipCert"] || {}
    primary_address = user_pii[:addresses]&.first || {}
    devlogs = review["devlogs"] || []
    banner_url = banner_url_for_project_id(ship_cert["ftProjectId"])

    {
      "review_id" => review["id"].to_s,
      "slack_id" => user_pii[:slack_id],
      "Email" => user_pii[:email],
      "First Name" => user_pii[:first_name],
      "Last Name" => user_pii[:last_name],
      "display_name" => user_pii[:display_name],
      "Address (Line 1)" => primary_address["line_1"],
      "Address (Line 2)" => primary_address["line_2"],
      "City" => primary_address["city"],
      "State / Province" => primary_address["state"],
      "ZIP / Postal Code" => primary_address["postal_code"],
      "Country" => primary_address["country"],
      "Birthday" => user_pii[:birthday],
      "ship_cert_id" => ship_cert["id"].to_s,
      "status" => review["status"],
      "synced_at" => Time.current.iso8601,
      "reviewer" => review.dig("reviewer", "username"),
      "Code URL" => ship_cert["repoUrl"],
      "Playable URL" => ship_cert["demoUrl"],
      "project_readme" => ship_cert["readmeUrl"],
      "Screenshot" => banner_url.present? ? [ { "url" => banner_url } ] : [ { "url" => ship_cert["screenshotUrl"] } ],
      "proof_video" => ship_cert["proofVideoUrl"].present? ? [ { "url" => ship_cert["proofVideoUrl"] } ] : nil,
      "Description" => ship_cert["description"],
      "Optional - Override Hours Spent" => (calculate_total_approved_minutes(devlogs) / 60.0).round(2),
      "Optional - Override Hours Spent Justification" => build_justification(review, devlogs, approved_orders)
    }
  end

  def calculate_total_approved_minutes(devlogs)
    return nil if devlogs.empty?

    devlogs.sum { |d| d["approvedMins"].to_i }
  end

  def build_justification(review, devlogs, approved_orders)
    return nil if devlogs.empty?

    ship_cert = review["shipCert"] || {}
    reviewer_username = review.dig("reviewer", "username") || "Unknown"
    ship_certifier = ship_cert["certifierName"] || "a ship certifier"
    project_id = ship_cert["ftProjectId"]
    review_id = review["id"]
    ship_cert_id = ship_cert["id"]

    total_original_seconds = devlogs.sum { |d| d["origSecs"].to_i }
    total_original_minutes = total_original_seconds / 60
    total_hours = total_original_minutes / 60
    original_time_remaining_minutes = total_original_minutes % 60
    original_time_formatted = total_hours > 0 ? "#{total_hours}h #{original_time_remaining_minutes}min" : "#{original_time_remaining_minutes}min"

    total_approved_minutes = devlogs.sum { |d| d["approvedMins"].to_i }
    approved_hours = total_approved_minutes / 60
    approved_time_remaining_minutes = total_approved_minutes % 60
    approved_time_formatted = approved_hours > 0 ? "#{approved_hours}h #{approved_time_remaining_minutes}min" : "#{approved_time_remaining_minutes}min"

    selected_devlogs = devlogs.count > 4 ? [ devlogs.first ] + devlogs.last(3) : devlogs
    devlog_list = selected_devlogs.map do |d|
      title = d["title"].presence || "devlog ##{d['id']}"
      approved = d["approvedMins"].to_i
      "#{title}: #{approved} mins"
    end.join("\n")
    devlog_list += "\nand #{devlogs.count - 4} more devlogs." if devlogs.count > 4

    orders_section = build_orders_section(approved_orders)

    <<~JUSTIFICATION
      The user logged #{original_time_formatted} on hackatime. #{total_original_minutes == total_approved_minutes ? "" : "(This was adjusted to #{approved_time_formatted} after review.)"}

      In this time they wrote #{devlogs.count} devlogs.

      This project was initially ship certified by #{ship_certifier}.

      Following this it was YSWS reviewed by #{reviewer_username}.

      #{reviewer_username} approved:

      #{devlog_list}
      ====================================================
      The flavortown project can be found at https://flavortown.hackclub.com/projects/#{project_id}

      The Full YSWS Review + devlogs are at https://review.hackclub.com/admin/ysws_reviews/#{review_id}

      The Ship Cert is at https://review.hackclub.com/admin/ship_certifications/#{ship_cert_id}/edit
      ====================================================
      #{orders_section}
    JUSTIFICATION
  end

  def build_orders_section(approved_orders)
    manual_orders = approved_orders.reject { |order| order.fulfilled_by == "System" }
    return "" if manual_orders.empty?

    orders_list = manual_orders.last(2).map do |order|
      item_name = order.shop_item.name
      fulfilled_by = order.fulfilled_by.presence || "Unknown"
      fulfilled_at = order.fulfilled_at&.strftime("%Y-%m-%d") || "Unknown date"
      "#{item_name} (x#{order.quantity}) - approved by #{fulfilled_by} on #{fulfilled_at}"
    end.join("\n")

    <<~ORDERS
      This user has the following manually approved shop orders:
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

  def banner_url_for_project_id(ft_project_id)
    Rails.logger.info("[YswsReviewSyncJob] banner_url_for_project_id: start ft_project_id=#{ft_project_id.inspect} (class=#{ft_project_id.class})")

    if ft_project_id.blank?
      Rails.logger.warn("[YswsReviewSyncJob] banner_url_for_project_id: ft_project_id is blank")
      return nil
    end

    project = Project.find_by(id: ft_project_id)
    if project.nil?
      Rails.logger.warn("[YswsReviewSyncJob] banner_url_for_project_id: Project not found by id=#{ft_project_id.inspect}")
      return nil
    end

    unless project.banner.attached?
      Rails.logger.warn("[YswsReviewSyncJob] banner_url_for_project_id: Project #{project.id} has no banner attached")
      return nil
    end

    host = default_url_host
    if host.blank?
      Rails.logger.error("[YswsReviewSyncJob] banner_url_for_project_id: host missing. action_mailer=#{Rails.application.config.action_mailer.default_url_options.inspect} routes=#{Rails.application.routes.default_url_options.inspect} ENV[APP_HOST]=#{ENV['APP_HOST'].inspect}")
      return nil
    end

    url = rails_blob_url(project.banner, host: host)
    Rails.logger.info("[YswsReviewSyncJob] banner_url_for_project_id: success project_id=#{project.id} url=#{url}")
    url
  rescue StandardError => e
    Rails.logger.error("[YswsReviewSyncJob] banner_url_for_project_id: exception project_id=#{ft_project_id.inspect} #{e.class}: #{e.message}")
    nil
  end

  def default_url_host
    ENV["APP_HOST"]
  end

  def project_exists_in_unified_db?(code_url)
    unified_db_table.all(
      filter: "AND({Code URL} = '#{code_url}', NOT({YSWS} = 'Flavortown'))"
    ).any?
  end

  def unified_db_table
    @unified_db_table ||= Norairrecord.table(
      ENV["UNIFIED_DB_INTEGRATION_AIRTABLE_KEY"],
      "app3A5kJwYqxMLOgh",
      "Approved Projects"
    )
  end

  def project_has_active_reports?(ft_project_id)
    return false if ft_project_id.blank?

    Project::Report.where(project_id: ft_project_id, status: [ :pending, :reviewed ]).exists?
  end
end

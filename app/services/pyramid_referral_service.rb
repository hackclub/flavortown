class PyramidReferralService
  PRODUCTION_BASE_URL = "https://pyramid.hackclub.com"
  DEVELOPMENT_BASE_URL = "http://host.docker.internal:4444"

  class << self
    # Fetch the list of valid referral codes from Pyramid API
    def fetch_valid_referral_codes
      response = connection.get("api/v1/referrals_valid")

      if response.success?
        data = JSON.parse(response.body)
        data["referral_codes"] || []
      else
        Rails.logger.error "PyramidReferralService error: #{response.status} - #{response.body}"
        nil
      end
    rescue => e
      Rails.logger.error "PyramidReferralService exception: #{e.message}"
      nil
    end

    def fetch_dashboard_stats
      response = connection.get("api/v1/dashboard_stats")

      if response.success?
        JSON.parse(response.body)
      else
        Rails.logger.error "PyramidReferralService dashboard stats error: #{response.status} - #{response.body}"
        fallback_dashboard_stats || { "error" => "Pyramid dashboard stats are unavailable" }
      end
    rescue => e
      Rails.logger.error "PyramidReferralService dashboard stats exception: #{e.message}"
      fallback_dashboard_stats || { "error" => e.message }
    end

    # Sync enriched_ref by cross-checking user ref values against valid Pyramid codes.
    # All matching users are labelled "pyramid scheme" so they group under one attribution bucket.
    def sync_enriched_refs!
      valid_codes = fetch_valid_referral_codes
      return { success: false, error: "Failed to fetch valid referral codes" } unless valid_codes

      valid_codes_set = Set.new(valid_codes.filter_map { |code| normalize_referral_code(code) })

      users_with_refs = User.where.not(ref: [ nil, "" ])
      updated_count = 0
      checked_count = 0

      users_with_refs.find_each do |user|
        checked_count += 1
        normalized_ref = normalize_referral_code(user.ref)
        next unless valid_codes_set.include?(normalized_ref)

        if user.enriched_ref != "pyramid scheme"
          user.update!(enriched_ref: "pyramid scheme")
          updated_count += 1
        end
      end

      { success: true, updated_count: updated_count, checked_count: checked_count, valid_codes_count: valid_codes.size }
    rescue => e
      Rails.logger.error "PyramidReferralService.sync_enriched_refs! error: #{e.message}"
      { success: false, error: e.message }
    end

    private

    def fallback_dashboard_stats
      referrals_by_status = %w[pending id_verified completed].index_with do |status|
        fetch_referrals(status)
      end

      return if referrals_by_status.values.any?(&:nil?)

      all_referrals = referrals_by_status.values.flatten
      completed_referrals = referrals_by_status.fetch("completed")

      {
        "data_source" => "fallback_referrals_api",
        "partial_data" => true,
        "referrals" => {
          "pending" => referrals_by_status.fetch("pending").size,
          "id_verified" => referrals_by_status.fetch("id_verified").size,
          "completed" => completed_referrals.size,
          "total" => all_referrals.size
        },
        "posters" => {
          "pending_physical" => 0,
          "rejected_physical" => 0,
          "completed_physical" => 0,
          "completed_digital" => 0,
          "total" => 0
        },
        "activity" => fallback_activity_stats(all_referrals, completed_referrals)
      }
    rescue => e
      Rails.logger.error "PyramidReferralService fallback dashboard stats exception: #{e.message}"
      nil
    end

    def fetch_referrals(status)
      response = connection.get("api/v1/referrals", status: status)
      unless response.success?
        Rails.logger.error "PyramidReferralService referrals fallback error (#{status}): #{response.status} - #{response.body}"
        return
      end

      JSON.parse(response.body).fetch("referrals", [])
    rescue => e
      Rails.logger.error "PyramidReferralService referrals fallback exception (#{status}): #{e.message}"
      nil
    end

    def fallback_activity_stats(all_referrals, completed_referrals)
      first_seen_by_identifier = {}
      completed_hours_by_date = Hash.new(0.0)
      user_slack_ids = []

      all_referrals.each do |referral|
        created_at = parse_time(referral["created_at"])
        identifier = normalize_referral_code(referral["referred_identifier"])
        if created_at && identifier
          existing = first_seen_by_identifier[identifier]
          first_seen_by_identifier[identifier] = created_at.to_date if existing.nil? || created_at.to_date < existing
        end

        user_slack_ids << referral["referrer_slack_id"] if referral["referrer_slack_id"].present?
        referred_slack_id = referral.dig("metadata", "airtable_data", "slack_id")
        user_slack_ids << referred_slack_id if referred_slack_id.present?
      end

      completed_referrals.each do |referral|
        completed_at = parse_time(referral["completed_at"])
        next unless completed_at

        completed_hours_by_date[completed_at.to_date] += referral_hours(referral)
      end

      user_additions_by_date = first_seen_by_identifier.values.each_with_object(Hash.new(0)) do |date, counts|
        counts[date] += 1
      end

      referral_creations_by_date = Hash.new(0)
      all_referrals.each do |referral|
        created_at = parse_time(referral["created_at"])&.to_date
        referral_creations_by_date[created_at] += 1 if created_at
      end

      {
        "user_slack_ids" => user_slack_ids.uniq,
        "engaged_users" => first_seen_by_identifier.size,
        "total_hours_logged" => completed_referrals.sum { |referral| referral_hours(referral) }.round(1),
        "users_gained_last_week" => sum_last_n_days(user_additions_by_date, 7).to_i,
        "users_gained_previous_week" => sum_previous_n_days(user_additions_by_date, 7).to_i,
        "verified_hours_last_week" => sum_last_n_days(completed_hours_by_date, 7).round(1),
        "verified_hours_previous_week" => sum_previous_n_days(completed_hours_by_date, 7).round(1),
        "referrals_gained_last_week" => sum_last_n_days(referral_creations_by_date, 7).to_i,
        "referrals_gained_previous_week" => sum_previous_n_days(referral_creations_by_date, 7).to_i,
        "timeline" => build_fallback_timeline(all_referrals, user_additions_by_date, completed_hours_by_date)
      }
    end

    def build_fallback_timeline(all_referrals, user_additions_by_date, completed_hours_by_date)
      dates = all_referrals.flat_map do |referral|
        [
          parse_time(referral["created_at"])&.to_date,
          parse_time(referral["verified_at"])&.to_date,
          parse_time(referral["completed_at"])&.to_date
        ]
      end.compact

      start_date = dates.min || 30.days.ago.to_date
      end_date = Time.current.to_date
      created_counts = Hash.new(0)
      verified_counts = Hash.new(0)
      completed_counts = Hash.new(0)

      all_referrals.each do |referral|
        created_at = parse_time(referral["created_at"])&.to_date
        verified_at = parse_time(referral["verified_at"])&.to_date
        completed_at = parse_time(referral["completed_at"])&.to_date

        created_counts[created_at] += 1 if created_at
        verified_counts[verified_at] += 1 if verified_at
        completed_counts[completed_at] += 1 if completed_at
      end

      (start_date..end_date).map do |date|
        {
          "date" => date.iso8601,
          "users_added" => user_additions_by_date[date] || 0,
          "referrals_created" => created_counts[date] || 0,
          "referrals_verified" => verified_counts[date] || 0,
          "referrals_completed" => completed_counts[date] || 0,
          "verified_hours" => (completed_hours_by_date[date] || 0).round(1),
          "posters_created" => 0,
          "posters_approved" => 0,
          "posters_rejected" => 0
        }
      end
    end

    def referral_hours(referral)
      metadata_hours = referral.dig("metadata", "hours")
      metadata_hours = referral.dig("metadata", "airtable_data", "hours") if metadata_hours.blank?
      return metadata_hours.to_f if metadata_hours.present?

      referral.fetch("tracked_minutes", 0).to_f / 60
    end

    def parse_time(value)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def sum_last_n_days(counts, days)
      ((days - 1).days.ago.to_date..Time.current.to_date).sum { |date| counts[date].to_f }
    end

    def sum_previous_n_days(counts, days)
      end_date = days.days.ago.to_date
      start_date = ((days * 2) - 1).days.ago.to_date
      (start_date..end_date).sum { |date| counts[date].to_f }
    end

    def connection
      Faraday.new(url: base_url) do |conn|
        conn.options.open_timeout = 2
        conn.options.timeout = 4
        conn.headers["Content-Type"] = "application/json"
        conn.headers["Authorization"] = "Bearer #{campaign_key}" if campaign_key.present?
        conn.headers["User-Agent"] = Rails.application.config.user_agent
      end
    end

    def base_url
      ENV["PYRAMID_BASE_URL"].presence || (Rails.env.production? ? PRODUCTION_BASE_URL : DEVELOPMENT_BASE_URL)
    end

    def campaign_key
      ENV["PYRAMID_CAMPAIGN_KEY"].presence
    end

    def normalize_referral_code(code)
      code.to_s.strip.downcase.presence
    end
  end
end

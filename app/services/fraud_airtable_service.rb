# frozen_string_literal: true

class FraudAirtableService
  # In production, uses Redis cache (15 minute TTL)
  # In development, no caching (always fresh data)
  CACHE_DURATION = 15.minutes

  def self.fetch_fraud_happy_by_week
    if Rails.env.production?
      Rails.cache.fetch("fraud_airtable_happiness_data", expires_in: CACHE_DURATION) do
        new.fetch_and_process
      end
    else
      new.fetch_and_process
    end
  end

  def self.fetch_vibes_history
    if Rails.env.production?
      Rails.cache.fetch("fraud_airtable_vibes_history", expires_in: CACHE_DURATION) do
        new.fetch_and_process_history
      end
    else
      new.fetch_and_process_history
    end
  end

  def fetch_and_process_history
    happiness_table = Norairrecord.table(airtable_api_key, airtable_base_id, "Fraud happy")
    all_records = happiness_table.all
    return {} if all_records.nil? || all_records.empty?

    # Group records by week, calculate avg scores per week
    by_week = all_records.group_by { |r| r&.fields&.dig("week")&.to_s }.compact.reject { |k, _| k.blank? }
    by_week.transform_values do |records|
      feelings = records.map { |r| feeling_to_score(r.fields["feeling"]) }.compact
      shop = records.map { |r| feeling_to_score(r.fields["shop order feeling"]) }.compact
      reports = records.map { |r| feeling_to_score(r.fields["reports order feeling"]) }.compact

      {
        avg_feeling: feelings.any? ? (feelings.sum.to_f / feelings.count).round(2) : nil,
        avg_shop: shop.any? ? (shop.sum.to_f / shop.count).round(2) : nil,
        avg_reports: reports.any? ? (reports.sum.to_f / reports.count).round(2) : nil,
        responses: records.count,
        records: records.map { |r|
          f = r.fields
          {
            email: f["email"],
            feeling: f["feeling"],
            shop_order_feeling: f["shop order feeling"],
            reports_order_feeling: f["reports order feeling"],
            extra_comments: f["extra comments"],
            feedback_impl: f["feedback_impl"] == true
          }
        }
      }
    end
  rescue StandardError => e
    Rails.logger.error("[FraudAirtableService] Error fetching vibes history: #{e.message}")
    {}
  end

  def fetch_and_process
    Rails.logger.info("[FraudAirtableService] Starting fetch_and_process")

    week = fetch_current_week
    Rails.logger.info("[FraudAirtableService] Fetched week: #{week.inspect}")

    return { week: nil, records: [], avg_scores: { total_responses: 0, responses_text: "0/0" }, error: "Could not fetch week from Fraud - Config" } if week.nil?

    records = fetch_fraud_happy_records(week)
    Rails.logger.info("[FraudAirtableService] Fetched #{records.count} records for week #{week}")

    total_team_size = fetch_total_team_size
    Rails.logger.info("[FraudAirtableService] Total team size: #{total_team_size}")

    avg_scores = calculate_average_scores(records)
    avg_scores[:responses_text] = "#{records.count}/#{total_team_size}"
    Rails.logger.info("[FraudAirtableService] Calculated scores: #{avg_scores.inspect}")

    {
      week: week,
      records: records,
      avg_scores: avg_scores,
      error: nil
    }
  rescue StandardError => e
    Rails.logger.error("[FraudAirtableService] Error fetching fraud data: #{e.message}")
    Rails.logger.error("[FraudAirtableService] Backtrace: #{e.backtrace.first(5).join("\n")}")
    {
      week: nil,
      records: [],
      avg_scores: { total_responses: 0, responses_text: "0/0" },
      error: e.message
    }
  end

  private

  def fetch_total_team_size
    Rails.logger.debug("[FraudAirtableService] Fetching total team size from 'Fraud - Config' table")

    config_table = Norairrecord.table(
      airtable_api_key,
      airtable_base_id,
      "Fraud - Config"
    )

    records = config_table.all
    return 0 if records.empty?

    first_record = records.first
    return 0 if first_record.nil?

    fields = first_record.fields
    return 0 if fields.nil?

    total = fields["Total Team Size"]
    Rails.logger.debug("[FraudAirtableService] Total team size: #{total.inspect}")
    total.to_i
  end

  def fetch_current_week
    Rails.logger.debug("[FraudAirtableService] Fetching from 'Fraud - Config' table")

    config_table = Norairrecord.table(
      airtable_api_key,
      airtable_base_id,
      "Fraud - Config"
    )

    records = config_table.all
    Rails.logger.debug("[FraudAirtableService] 'Fraud - Config' returned #{records.count} records")
    return nil if records.empty?

    # Get week from first column (first record, first field)
    first_record = records.first
    Rails.logger.debug("[FraudAirtableService] First record: #{first_record.inspect}")
    return nil if first_record.nil?

    fields = first_record.fields
    Rails.logger.debug("[FraudAirtableService] Fields: #{fields.inspect}")
    return nil if fields.nil?

    week = fields["Week"]
    Rails.logger.debug("[FraudAirtableService] Extracted week: #{week.inspect}")
    week
  end

  def fetch_fraud_happy_records(week)
    Rails.logger.debug("[FraudAirtableService] Fetching from 'Fraud happy' table for week: #{week.inspect}")

    happiness_table = Norairrecord.table(
      airtable_api_key,
      airtable_base_id,
      "Fraud happy"
    )

    all_records = happiness_table.all
    Rails.logger.debug("[FraudAirtableService] 'Fraud happy' returned #{all_records.count} total records")
    return [] if all_records.nil? || all_records.empty?

    # Filter by matching week
    matching_records = all_records.select do |record|
      record&.fields&.dig("week") == week
    end
    Rails.logger.debug("[FraudAirtableService] Found #{matching_records.count} records matching week #{week.inspect}")

    mapped_records = matching_records.map do |record|
      fields = record.fields
      next if fields.nil?

      {
        id: record.id,
        email: fields["email"],
        week: fields["week"],
        feeling: fields["feeling"],
        shop_order_feeling: fields["shop order feeling"],
        reports_order_feeling: fields["reports order feeling"],
        extra_comments: fields["extra comments"],
        feedback_impl: fields["feedback_impl"] == true
      }
    end.compact

    Rails.logger.debug("[FraudAirtableService] Mapped #{mapped_records.count} records")
    mapped_records
  end

  def calculate_average_scores(records)
    # Always return a hash with at least total_responses
    return { total_responses: 0 } if records.empty?

    # Convert feeling scores to numeric (1-5 scale)
    feelings = records.map { |r| feeling_to_score(r[:feeling]) }.compact
    shop_order_feelings = records.map { |r| feeling_to_score(r[:shop_order_feeling]) }.compact
    reports_order_feelings = records.map { |r| feeling_to_score(r[:reports_order_feeling]) }.compact

    {
      avg_feeling: feelings.any? ? (feelings.sum.to_f / feelings.count).round(2) : nil,
      avg_shop_order_feeling: shop_order_feelings.any? ? (shop_order_feelings.sum.to_f / shop_order_feelings.count).round(2) : nil,
      avg_reports_order_feeling: reports_order_feelings.any? ? (reports_order_feelings.sum.to_f / reports_order_feelings.count).round(2) : nil,
      total_responses: records.count
    }
  end

  def feeling_to_score(feeling)
    # Handle nil and numeric values
    return nil if feeling.nil?
    return feeling.to_i if feeling.is_a?(Integer)

    # Convert to string and normalize
    feeling_str = feeling.to_s.downcase.strip

    case feeling_str
    when "😭", "very unhappy", "very unhappy (crying face)" then 1
    when "😞", "unhappy", "unhappy (sad face)" then 2
    when "😐", "neutral", "neutral (neutral face)" then 3
    when "🙂", "happy", "happy (smiling face)" then 4
    when "😄", "very happy", "very happy (very happy face)" then 5
    else
      nil
    end
  end

  def airtable_api_key
    @airtable_api_key ||= Rails.application.credentials&.airtable&.api_key || ENV["AIRTABLE_API_KEY"]
  end

  def airtable_base_id
    @airtable_base_id ||= Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"]
  end
end

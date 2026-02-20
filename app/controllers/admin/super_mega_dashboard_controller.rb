# frozen_string_literal: true

module Admin
  class SuperMegaDashboardController < Admin::ApplicationController
    def index
      authorize :admin, :access_super_mega_dashboard?

      load_fraud_stats
      load_payouts_stats
      load_fulfillment_stats
      load_support_stats
      load_support_vibes_stats
      load_support_graph_data
      load_ship_certs_stats
      load_sw_vibes_stats
      load_voting_stats
      load_ysws_review_stats
    end

    private

    def load_fraud_stats
      today = Time.current.beginning_of_day..Time.current.end_of_day

      report_counts = Project::Report.group(:status).count
      @fraud_reports = {
        pending: report_counts["pending"] || report_counts[0] || 0,
        reviewed: report_counts["reviewed"] || report_counts[1] || 0,
        dismissed: report_counts["dismissed"] || report_counts[2] || 0,
        new_today: Project::Report.where(created_at: today).count
      }

      ban_counts = User.where("banned = ? OR shadow_banned = ?", true, true)
                       .group(:banned, :shadow_banned).count
      @fraud_bans = {
        banned: ban_counts.sum { |(b, _), c| b ? c : 0 },
        shadow_banned_users: ban_counts.sum { |(_, sb), c| sb ? c : 0 }
      }

      order_counts = ShopOrder.group(:aasm_state).count
      pending = order_counts["pending"] || 0
      awaiting = order_counts["awaiting_periodical_fulfillment"] || 0
      @fraud_orders = {
        pending: pending,
        awaiting: awaiting,
        on_hold: order_counts["on_hold"] || 0,
        rejected: order_counts["rejected"] || 0,
        backlog: pending + awaiting,
        new_today: ShopOrder.where(created_at: today).count
      }
    end

    def load_payouts_stats
      @payouts_cap = LedgerEntry.sum(:amount)

      yesterday = 24.hours.ago
      recent = LedgerEntry.where(created_at: yesterday..)

      recent_stats = recent.pluck(
        Arel.sql("COALESCE(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 0)"),
        Arel.sql("COALESCE(SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END), 0)"),
        Arel.sql("COUNT(*)"),
        Arel.sql("COALESCE(SUM(ABS(amount)), 0)")
      ).first

      @payouts = {
        created: recent_stats[0],
        destroyed: recent_stats[1],
        txns: recent_stats[2],
        volume: recent_stats[3]
      }
    end

    def load_fulfillment_stats
      base_scope = ShopOrder.joins(:shop_item)
                            .where(aasm_state: %w[pending awaiting_periodical_fulfillment])
                            .where.not(shop_items: { type: "ShopItem::FreeStickers" })

      type_counts = base_scope.group("shop_items.type", :aasm_state).count

      @fulfillment = {
        all: calculate_type_totals(type_counts),
        hq_mail: calculate_type_totals(type_counts, %w[ShopItem::HQMailItem ShopItem::LetterMail]),
        third_party: calculate_type_totals(type_counts, %w[ShopItem::ThirdPartyPhysical]),
        warehouse: calculate_type_totals(type_counts, %w[ShopItem::WarehouseItem ShopItem::PileOfStickersItem]),
        other: calculate_type_totals(type_counts, %w[ShopItem::HCBGrant ShopItem::SiteActionItem ShopItem::BadgeItem ShopItem::AdventSticker ShopItem::HCBPreauthGrant ShopItem::SpecialFulfillmentItem])
      }
    end

    def calculate_type_totals(type_counts, filter_types = nil)
      pending = 0
      awaiting = 0

      type_counts.each do |(type, state), count|
        next if filter_types && !filter_types.include?(type)

        case state
        when "pending"
          pending += count
        when "awaiting_periodical_fulfillment"
          awaiting += count
        end
      end

      { pending: pending, awaiting: awaiting, total: pending + awaiting }
    end

    def load_support_stats
      response = Faraday.get("https://flavortown.nephthys.hackclub.com/api/stats_v2")
      data = JSON.parse(response.body)

      hang_24h = data.dig("past_24h", "mean_hang_time_minutes_all")
      hang_24h_prev = data.dig("past_24h_previous", "mean_hang_time_minutes_all")
      hang_7d = data.dig("past_7d", "mean_hang_time_minutes_all")
      hang_7d_prev = data.dig("past_7d_previous", "mean_hang_time_minutes_all")
      oldest = data.dig("all_time", "oldest_unanswered_ticket")

      @support = {
        hang_24h: hang_24h&.round,
        hang_24h_change: chg(hang_24h_prev, hang_24h),
        hang_7d: hang_7d&.round,
        hang_7d_change: chg(hang_7d_prev, hang_7d),
        oldest_unanswered: oldest&.dig("age_minutes")&.round,
        oldest_unanswered_link: oldest&.dig("link")
      }
    rescue Faraday::Error, JSON::ParserError
      @support = nil
    end

    def load_support_vibes_stats
      @latest_support_vibes = SupportVibes.order(period_end: :desc).first
    end

    def load_support_graph_data
      start_date = 30.days.ago.to_date
      end_date = Date.current
      response = Faraday.get("https://flavortown-support-stats.slevel.xyz/api/v1/super-mega-stats?start=#{start_date}&end=#{end_date}")
      data = JSON.parse(response.body)

      unresolved = data.dig("unresolved_tickets") || {}
      hang_time = data.dig("p95") || {}

      all_dates = (unresolved.keys + hang_time.keys).uniq.sort

      @support_graph_data = all_dates.map do |date|
        {
          date: date,
          unresolved_tickets: unresolved[date] || 0,
          hang_time_p95: hang_time[date].nil? ? nil : hang_time[date].round(2)
        }
      end
    rescue Faraday::Error, JSON::ParserError
      @support_graph_data = nil
    end

    def chg(old, new)
      return nil if old.nil? || new.nil? || old.zero?

      ((new - old) / old.to_f * 100).round
    end

    def load_ship_certs_stats
      conn = Faraday.new do |f|
        f.options.timeout = 5
        f.options.open_timeout = 2
      end

      response = conn.get("https://review.hackclub.com/api/stats/ship-certs") do |req|
        req.headers["x-api-key"] = ENV["SW_DASHBOARD_API_KEY"]
      end

      unless response.success?
        @ship_certs = { error: true }
        return
      end

      data = JSON.parse(response.body)

      @ship_certs = {
        total_judged: data["totalJudged"],
        approved: data["approved"],
        rejected: data["rejected"],
        pending: data["pending"],
        approval_rate: data["approvalRate"],
        median_queue_time: data["medianQueueTime"],
        oldest_in_queue: data["oldestInQueue"],
        avg_queue_time_history: data["avgQueueTime"] || {},
        reviews_per_day: data["reviewsPerDay"] || {},
        ships_per_day: data["shipsPerDay"] || {},
        decisions_today: data["decisionsToday"],
        new_ships_today: data["newShipsToday"]
      }
    rescue Faraday::Error, JSON::ParserError, Faraday::TimeoutError
      @ship_certs = { error: true }
    end

    def load_sw_vibes_stats
      api_key = ENV["SWAI_KEY"]
      unless api_key.present?
        @sw_vibes = { error: "SWAI_KEY not configured" }
        return
      end

      @sw_vibes = Rails.cache.fetch("sw_vibes_data", expires_in: 5.minutes) do
        conn = Faraday.new do |f|
          f.options.timeout = 10
          f.options.open_timeout = 5
        end

        response = conn.get("https://ai.review.hackclub.com/metrics/qualitative") do |req|
          req.headers["X-API-Key"] = api_key
        end

        unless response.success?
          next { error: "API died (#{response.status})" }
        end

        JSON.parse(response.body, symbolize_names: true)
      end
    rescue Faraday::Error
      @sw_vibes = { error: "Couldn't reach the API" }
    rescue JSON::ParserError
      @sw_vibes = { error: "Got a weird response" }
    end

    def load_voting_stats
      today = Time.current.beginning_of_day..Time.current.end_of_day
      this_week = 7.days.ago.beginning_of_day..Time.current

      avg_columns = Vote.enabled_categories.map do |category|
        column = Vote.score_column_for!(category)
        "AVG(#{column}) AS avg_#{category}"
      end.join(", ")

      select_sql = Vote.sanitize_sql_array([
        <<-SQL.squish,
          COUNT(*) AS total_votes,
          COUNT(*) FILTER (WHERE created_at >= ? AND created_at <= ?) AS votes_today,
          COUNT(*) FILTER (WHERE created_at >= ?) AS votes_this_week,
          AVG(time_taken_to_vote) AS avg_time,
          COUNT(*) FILTER (WHERE repo_url_clicked = true) AS repo_clicks,
          COUNT(*) FILTER (WHERE demo_url_clicked = true) AS demo_clicks,
          COUNT(*) FILTER (WHERE reason IS NOT NULL AND reason != '') AS with_reason,
          #{avg_columns}
        SQL
        today.begin, today.end, this_week.begin
      ])

      vote_stats = Vote.select(select_sql).take
      total = vote_stats.total_votes.to_i

      @voting_overview = {
        total: total,
        today: vote_stats.votes_today.to_i,
        this_week: vote_stats.votes_this_week.to_i,
        avg_time_seconds: vote_stats.avg_time&.round,
        repo_click_rate: total > 0 ? (vote_stats.repo_clicks.to_f / total * 100).round(1) : 0,
        demo_click_rate: total > 0 ? (vote_stats.demo_clicks.to_f / total * 100).round(1) : 0,
        reason_rate: total > 0 ? (vote_stats.with_reason.to_f / total * 100).round(1) : 0
      }

      @voting_category_avgs = Vote.enabled_categories.index_with do |category|
        vote_stats.send(:"avg_#{category}")&.to_f&.round(2)
      end
    end

    def load_ysws_review_stats
      # Build 14-day trend data using EST timezone
      est_timezone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      @ysws_review_graph_data = {
        done: {},
        returned: {}
      }

      # Generate data for each of the last 14 days in EST
      (0..13).reverse_each do |days_ago|
        date = days_ago.days.ago.in_time_zone(est_timezone).to_date

        if days_ago == 0
          # For today, calculate hours since midnight EST and call API directly
          now_est = Time.current.in_time_zone(est_timezone)
          midnight_est = now_est.beginning_of_day
          hours_since_midnight = ((now_est - midnight_est) / 1.hour).round
          done_count = find_number_of_reviews(hours_since_midnight, "done")
          returned_count = find_number_of_reviews(hours_since_midnight, "returned")
        else
          # For historical days, use the difference method
          done_count = find_reviews(days_ago, 24, "done")
          returned_count = find_reviews(days_ago, 24, "returned")
        end

        @ysws_review_graph_data[:done][date.to_s] = done_count
        @ysws_review_graph_data[:returned][date.to_s] = returned_count
      end

      # Calculate summary stats using EST dates
      today_est = Time.current.in_time_zone(est_timezone).to_date
      week_ago_est = 7.days.ago.in_time_zone(est_timezone).to_date

      done_total = @ysws_review_graph_data[:done].values.sum
      returned_total = @ysws_review_graph_data[:returned].values.sum

      @ysws_review_stats = {
        total: done_total + returned_total,
        done_total: done_total,
        returned_total: returned_total,
        today: (@ysws_review_graph_data[:done][today_est.to_s] || 0) + (@ysws_review_graph_data[:returned][today_est.to_s] || 0),
        this_week: (@ysws_review_graph_data[:done].select { |date, _| Date.parse(date) >= week_ago_est }.sum { |_, count| count }) +
                   (@ysws_review_graph_data[:returned].select { |date, _| Date.parse(date) >= week_ago_est }.sum { |_, count| count })
      }
    rescue StandardError => e
      Rails.logger.error "[SuperMegaDashboard] Error loading YSWS review stats: #{e.message}"
      Rails.logger.error "[SuperMegaDashboard] Backtrace: #{e.backtrace.first(5).join("\n")}"
      @ysws_review_graph_data = nil
      @ysws_review_stats = { error: e.message }
    end

    def find_reviews(days, offset_hours, status)
      # Total reviews by day before (at the start of the day)
      total_by_day_before = find_number_of_reviews(days * 24, status)

      # Total reviews by end of day (after offset_hours)
      total_by_end_of_day = find_number_of_reviews(days * 24 + offset_hours, status)

      # Total for the day = difference
      total_by_end_of_day - total_by_day_before
    end

    def find_number_of_reviews(hours, status)
      response_data = YswsReviewService.fetch_reviews(hours: hours, status: status)

      # Handle different response formats - API might return a hash or array
      reviews_data = if response_data.is_a?(Hash)
        response_data["reviews"] || response_data[:reviews] || []
      elsif response_data.is_a?(Array)
        response_data
      else
        []
      end

      reviews_data.size
    end
  end
end

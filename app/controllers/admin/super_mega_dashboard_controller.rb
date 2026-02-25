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
      load_voting_stats
      load_ysws_review_stats
    end

    def load_section
      authorize :admin, :access_super_mega_dashboard?

      section = params[:section]

      case section
      when "shipwrights"
        load_ship_certs_stats
        load_sw_vibes_stats
        load_sw_vibes_history
        render partial: "admin/super_mega_dashboard/sections/shipwrights", layout: false
      else
        render plain: "Unknown section", status: :bad_request
      end
    end

    private

    def load_fraud_stats
      cached_data = Rails.cache.fetch("super_mega_fraud_stats", expires_in: 5.minutes) do
        begin
          today = Time.current.beginning_of_day..Time.current.end_of_day

          report_counts = Project::Report.group(:status).count
          total_reports = report_counts.values.sum
          pending = report_counts["pending"] || report_counts[0] || 0
          reviewed = report_counts["reviewed"] || report_counts[1] || 0
          dismissed = report_counts["dismissed"] || report_counts[2] || 0
          new_today_reports = Project::Report.where(created_at: today).count

          fraud_reports = {
            pending: pending,
            pending_pct: total_reports > 0 ? ((pending.to_f / total_reports) * 100).round(1) : 0,
            reviewed: reviewed,
            reviewed_pct: total_reports > 0 ? ((reviewed.to_f / total_reports) * 100).round(1) : 0,
            dismissed: dismissed,
            dismissed_pct: total_reports > 0 ? ((dismissed.to_f / total_reports) * 100).round(1) : 0,
            new_today: new_today_reports
          }

          ban_counts = User.where("banned = ? OR shadow_banned = ?", true, true)
                           .group(:banned, :shadow_banned).count
          total_users = User.count
          banned = ban_counts.sum { |(b, _), c| b ? c : 0 }
          shadow_banned = ban_counts.sum { |(_, sb), c| sb ? c : 0 }

          fraud_bans = {
            banned: banned,
            banned_pct: total_users > 0 ? ((banned.to_f / total_users) * 100).round(2) : 0,
            shadow_banned_users: shadow_banned,
            shadow_banned_pct: total_users > 0 ? ((shadow_banned.to_f / total_users) * 100).round(2) : 0
          }

          # Second chances vs bans (ban changes today)
          bans_today = PaperTrail::Version.where(item_type: "User", created_at: today)
                                          .where("object_changes ->> 'banned' IS NOT NULL")
                                          .where("object_changes -> 'banned' ->> 1 = ?", "true").count
          unbans_today = PaperTrail::Version.where(item_type: "User", created_at: today)
                                            .where("object_changes ->> 'banned' IS NOT NULL")
                                            .where("object_changes -> 'banned' ->> 1 = ?", "false").count

          fraud_second_chances = {
            bans_today: bans_today,
            unbans_today: unbans_today,
            net_change: bans_today - unbans_today
          }

          # Fraud dept only handles: pending, awaiting_verification, on_hold, rejected
          fraud_order_counts = ShopOrder.where(aasm_state: %w[pending awaiting_verification on_hold rejected])
                                        .group(:aasm_state).count
          pending = fraud_order_counts["pending"] || 0
          awaiting_verification = fraud_order_counts["awaiting_verification"] || 0
          total_fraud_orders = fraud_order_counts.values.sum
          backlog = pending + awaiting_verification
          on_hold = fraud_order_counts["on_hold"] || 0
          rejected = fraud_order_counts["rejected"] || 0
          new_today_orders = ShopOrder.where(aasm_state: %w[pending awaiting_verification on_hold rejected], created_at: today).count

          fraud_orders = {
            pending: pending,
            pending_pct: backlog > 0 ? ((pending.to_f / backlog) * 100).round(1) : 0,
            awaiting: awaiting_verification,
            awaiting_pct: backlog > 0 ? ((awaiting_verification.to_f / backlog) * 100).round(1) : 0,
            on_hold: on_hold,
            rejected: rejected,
            backlog: backlog,
            backlog_pct: total_fraud_orders > 0 ? ((backlog.to_f / total_fraud_orders) * 100).round(1) : 0,
            new_today: new_today_orders
          }

          {
            fraud_reports: fraud_reports,
            fraud_bans: fraud_bans,
            fraud_second_chances: fraud_second_chances,
            fraud_orders: fraud_orders,
            joe_fraud_stats: fetch_joe_fraud_stats,
            fraud_ban_trend_data: build_ban_trend_data,
            fraud_shop_order_trend_data: build_shop_order_trend_data,
            fraud_report_trend_data: build_report_trend_data
          }
        rescue StandardError => e
          Rails.logger.error("[SuperMegaDashboard] Error in load_fraud_stats: #{e.message}")
          {
            fraud_reports: {},
            fraud_bans: {},
            fraud_second_chances: {},
            fraud_orders: {},
            joe_fraud_stats: { error: "Joe error" },
            fraud_ban_trend_data: {},
            fraud_shop_order_trend_data: {},
            fraud_report_trend_data: {}
          }
        end
      end

      @fraud_reports = cached_data&.dig(:fraud_reports) || {}
      @fraud_bans = cached_data&.dig(:fraud_bans) || {}
      @fraud_second_chances = cached_data&.dig(:fraud_second_chances) || {}
      @fraud_orders = cached_data&.dig(:fraud_orders) || {}
      @joe_fraud_stats = cached_data&.dig(:joe_fraud_stats) || {}
      @fraud_ban_trend_data = cached_data&.dig(:fraud_ban_trend_data) || {}
      @fraud_shop_order_trend_data = cached_data&.dig(:fraud_shop_order_trend_data) || {}
      @fraud_report_trend_data = cached_data&.dig(:fraud_report_trend_data) || {}
    end

    private

    def build_ban_trend_data
      Rails.cache.fetch("super_mega_ban_trend", expires_in: 1.hour) do
        trend_data = {}
        # Get data for last 30 days
        (0..29).reverse_each do |days_ago|
          date = days_ago.days.ago.to_date
          day_range = date.beginning_of_day..date.end_of_day

          bans = PaperTrail::Version.where(item_type: "User", created_at: day_range)
                                    .where("object_changes ->> 'banned' IS NOT NULL")
                                    .where("object_changes -> 'banned' ->> 1 = ?", "true").count
          unbans = PaperTrail::Version.where(item_type: "User", created_at: day_range)
                                      .where("object_changes ->> 'banned' IS NOT NULL")
                                      .where("object_changes -> 'banned' ->> 1 = ?", "false").count

          trend_data[date.to_s] = { bans: bans, unbans: unbans }
        end
        trend_data
      end
    end

    def build_shop_order_trend_data
      Rails.cache.fetch("super_mega_order_trend", expires_in: 1.hour) do
        trend_data = {}
        # Get data for last 30 days - fraud dept only (pending, awaiting_verification, on_hold, rejected)
        (0..29).reverse_each do |days_ago|
          date = days_ago.days.ago.to_date
          day_range = date.beginning_of_day..date.end_of_day

          # Count shop orders by state on this day (fraud dept only)
          states = %w[pending awaiting_verification rejected on_hold]
          state_counts = ShopOrder.where(updated_at: day_range)
                                  .where(aasm_state: states)
                                  .group(:aasm_state).count

          trend_data[date.to_s] = state_counts.transform_keys(&:to_s)
        end
        trend_data
      end
    end

    def build_report_trend_data
      Rails.cache.fetch("super_mega_report_trend", expires_in: 1.hour) do
        trend_data = {}
        # Get data for last 30 days
        (0..29).reverse_each do |days_ago|
          date = days_ago.days.ago.to_date
          day_range = date.beginning_of_day..date.end_of_day

          # Count fraud reports by reason on this day
          reason_counts = Project::Report.where(updated_at: day_range)
                                         .group(:reason).count

          trend_data[date.to_s] = reason_counts
        end
        trend_data
      end
    end



    def calculate_review_quality
      # Average time to review reports
      reviewed_reports = Project::Report.where(status: %w[reviewed dismissed])
                                        .pluck(:created_at, :updated_at)

      if reviewed_reports.any?
        avg_review_hours = reviewed_reports.map { |(created, updated)| ((updated - created) / 1.hour).round(1) }.sum / reviewed_reports.count
      else
        avg_review_hours = 0
      end

      total_reviewed = Project::Report.where(status: %w[reviewed dismissed]).count
      this_week_reviewed = Project::Report.where(status: %w[reviewed dismissed], updated_at: 7.days.ago..).count

      {
        total_reviewed: total_reviewed,
        avg_review_hours: avg_review_hours.round(1),
        this_week: this_week_reviewed
      }
    end

    def fetch_joe_fraud_stats
      Rails.cache.fetch("joe_fraud_stats", expires_in: 5.minutes) do
        api_key = ENV["NEONS_JOE_COOKIES"]
        unless api_key.present?
          return { error: "NEONS_JOE_COOKIES not configured" }
        end

        conn = Faraday.new do |f|
          f.options.timeout = 10
          f.options.open_timeout = 5
        end

        response = conn.get("https://joe.fraud.hackclub.com/api/v1/cases/stats?ysws=flavortown") do |req|
          req.headers["Cookie"] = api_key
        end

        unless response.success?
          return { error: "API returned #{response.status}" }
        end

        data = JSON.parse(response.body, symbolize_names: true)

        {
          total: data[:total] || 0,
          open: data[:open] || 0,
          closed: data[:closed] || 0,
          second_chances_given: data.dig(:byStatus, :second_chance_given) || 0,
          fraudpheus_open: data.dig(:byStatus, :fraudpheus_open) || 0,
          timeline: data[:timeline] || [],
          cases_opened: data[:casesOpened] || []
        }
      end
    rescue Faraday::Error
      { error: "Couldn't reach the API" }
    rescue JSON::ParserError
      { error: "Got a weird response" }
    end

    def load_payouts_stats
      cached_data = Rails.cache.fetch("super_mega_payouts", expires_in: 10.minutes) do
        payouts_cap = LedgerEntry.sum(:amount)
        yesterday = 24.hours.ago
        recent = LedgerEntry.where(created_at: yesterday..)

        recent_stats = recent.pluck(
          Arel.sql("COALESCE(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 0)"),
          Arel.sql("COALESCE(SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END), 0)"),
          Arel.sql("COUNT(*)"),
          Arel.sql("COALESCE(SUM(ABS(amount)), 0)")
        ).first

        {
          payouts_cap: payouts_cap,
          payouts: {
            created: recent_stats[0],
            destroyed: recent_stats[1],
            txns: recent_stats[2],
            volume: recent_stats[3]
          }
        }
      end
      @payouts_cap = cached_data&.dig(:payouts_cap) || 0
      @payouts = cached_data&.dig(:payouts) || { created: 0, destroyed: 0, txns: 0, volume: 0 }
    end

    def load_fulfillment_stats
      cached_data = Rails.cache.fetch("super_mega_fulfillment", expires_in: 10.minutes) do
        base_scope = ShopOrder.joins(:shop_item)
                              .where(aasm_state: %w[pending awaiting_periodical_fulfillment])
                              .where.not(shop_items: { type: "ShopItem::FreeStickers" })

        type_counts = base_scope.group("shop_items.type", :aasm_state).count

        {
          all: calculate_type_totals(type_counts),
          hq_mail: calculate_type_totals(type_counts, %w[ShopItem::HQMailItem ShopItem::LetterMail]),
          third_party: calculate_type_totals(type_counts, %w[ShopItem::ThirdPartyPhysical]),
          warehouse: calculate_type_totals(type_counts, %w[ShopItem::WarehouseItem ShopItem::PileOfStickersItem]),
          other: calculate_type_totals(type_counts, %w[ShopItem::HCBGrant ShopItem::SiteActionItem ShopItem::BadgeItem ShopItem::AdventSticker ShopItem::HCBPreauthGrant ShopItem::SpecialFulfillmentItem])
        }
      end
      @fulfillment = cached_data || { all: {}, hq_mail: {}, third_party: {}, warehouse: {}, other: {} }
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
      @support = Rails.cache.fetch("super_mega_support", expires_in: 5.minutes) do
        begin
          response = Faraday.get("https://flavortown.nephthys.hackclub.com/api/stats_v2")
          data = JSON.parse(response.body)

          hang_24h = data.dig("past_24h", "mean_hang_time_minutes_all")
          hang_24h_prev = data.dig("past_24h_previous", "mean_hang_time_minutes_all")
          hang_7d = data.dig("past_7d", "mean_hang_time_minutes_all")
          hang_7d_prev = data.dig("past_7d_previous", "mean_hang_time_minutes_all")
          oldest = data.dig("all_time", "oldest_unanswered_ticket")

          {
            hang_24h: hang_24h&.round,
            hang_24h_change: chg(hang_24h_prev, hang_24h),
            hang_7d: hang_7d&.round,
            hang_7d_change: chg(hang_7d_prev, hang_7d),
            oldest_unanswered: oldest&.dig("age_minutes")&.round,
            oldest_unanswered_link: oldest&.dig("link")
          }
        rescue Faraday::Error, JSON::ParserError
          nil
        end
      end
    end

    def load_support_vibes_stats
      @latest_support_vibes = Rails.cache.fetch("super_mega_support_vibes", expires_in: 1.hour) do
        SupportVibes.order(period_end: :desc).first
      end
    end

    def load_support_graph_data
      @support_graph_data = Rails.cache.fetch("super_mega_support_graph", expires_in: 10.minutes) do
        begin
          start_date = 30.days.ago.to_date
          end_date = Date.current
          response = Faraday.get("https://flavortown-support-stats.slevel.xyz/api/v1/super-mega-stats?start=#{start_date}&end=#{end_date}")
          data = JSON.parse(response.body)

          unresolved = data.dig("unresolved_tickets") || {}
          hang_time = data.dig("p95") || {}

          all_dates = (unresolved.keys + hang_time.keys).uniq.sort

          all_dates.map do |date|
            {
              date: date,
              unresolved_tickets: unresolved[date] || 0,
              hang_time_p95: hang_time[date].nil? ? nil : hang_time[date].round(2)
            }
          end
        rescue Faraday::Error, JSON::ParserError
          nil
        end
      end
    end

    def chg(old, new)
      return nil if old.nil? || new.nil? || old.zero?

      ((new - old) / old.to_f * 100).round
    end

    def load_ship_certs_stats
      raw_data = Rails.cache.read("super_mega_ship_certs_raw")

      unless raw_data
        begin
          conn = Faraday.new do |f|
            f.options.timeout = 5
            f.options.open_timeout = 2
          end

          response = conn.get("https://review.hackclub.com/api/stats/ship-certs") do |req|
            req.headers["x-api-key"] = ENV["SW_DASHBOARD_API_KEY"]
          end

          if response.success?
            raw_data = JSON.parse(response.body)
            Rails.cache.write("super_mega_ship_certs_raw", raw_data, expires_in: 10.minutes)
          else
            raw_data = :error
            Rails.cache.write("super_mega_ship_certs_raw", raw_data, expires_in: 1.minute)
          end
        rescue Faraday::Error, JSON::ParserError, Faraday::TimeoutError
          raw_data = :error
          Rails.cache.write("super_mega_ship_certs_raw", raw_data, expires_in: 1.minute)
        end
      end

      if raw_data.nil? || raw_data == :error
        @ship_certs = { error: true }
        return
      end

      @ship_certs = {
        total_judged: raw_data["totalJudged"],
        approved: raw_data["approved"],
        rejected: raw_data["rejected"],
        pending: raw_data["pending"],
        approval_rate: raw_data["approvalRate"],
        median_queue_time: raw_data["medianQueueTime"],
        oldest_in_queue: raw_data["oldestInQueue"],
        avg_queue_time_history: raw_data["avgQueueTime"] || {},
        reviews_per_day: raw_data["reviewsPerDay"] || {},
        ships_per_day: raw_data["shipsPerDay"] || {},
        decisions_today: raw_data["decisionsToday"],
        new_ships_today: raw_data["newShipsToday"]
      }

      @sw_vibes_history = parse_sw_vibes_history(raw_data["metricsHistory"] || [])
    end

    def load_sw_vibes_stats
      api_key = ENV["SWAI_KEY"]
      unless api_key.present?
        @sw_vibes = { error: "SWAI_KEY not configured" }
        return
      end

      cached = Rails.cache.read("sw_vibes_data")
      if cached
        @sw_vibes = cached
        return
      end

      begin
        conn = Faraday.new do |f|
          f.options.timeout = 10
          f.options.open_timeout = 5
        end

        response = conn.get("https://ai.review.hackclub.com/metrics/qualitative") do |req|
          req.headers["X-API-Key"] = api_key
        end

        unless response.success?
          @sw_vibes = { error: "API died (#{response.status})" }
          return
        end

        data = JSON.parse(response.body, symbolize_names: true)
        Rails.cache.write("sw_vibes_data", data, expires_in: 10.minutes)
        @sw_vibes = data
      rescue Faraday::Error
        @sw_vibes = { error: "Couldn't reach the API" }
      rescue JSON::ParserError
        @sw_vibes = { error: "Got a weird response" }
      end
    end

    def load_sw_vibes_history
      @sw_vibes_history ||= []
    end

    def parse_sw_vibes_history(metrics_history)
      metrics_history.filter_map do |entry|
        output = entry["output"] || {}
        date_str = output["for_date"]
        next unless date_str.present?

        inner = output["output"] || {}
        positive = inner["positive"] || {}

        OpenStruct.new(
          recorded_date: Date.parse(date_str),
          result: positive["result"],
          reason: positive["reason"],
          sentiment: positive["sentiment"],
          payload: inner
        )
      rescue Date::Error
        nil
      end.sort_by(&:recorded_date).reverse
    end

    def load_voting_stats
      cached_data = Rails.cache.fetch("super_mega_voting", expires_in: 10.minutes) do
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

        voting_overview = {
          total: total,
          today: vote_stats.votes_today.to_i,
          this_week: vote_stats.votes_this_week.to_i,
          avg_time_seconds: vote_stats.avg_time&.round,
          repo_click_rate: total > 0 ? (vote_stats.repo_clicks.to_f / total * 100).round(1) : 0,
          demo_click_rate: total > 0 ? (vote_stats.demo_clicks.to_f / total * 100).round(1) : 0,
          reason_rate: total > 0 ? (vote_stats.with_reason.to_f / total * 100).round(1) : 0
        }

        voting_category_avgs = Vote.enabled_categories.index_with do |category|
          vote_stats.send(:"avg_#{category}")&.to_f&.round(2)
        end

        {
          overview: voting_overview,
          category_avgs: voting_category_avgs
        }
      end

      @voting_overview = cached_data&.dig(:overview) || {}
      @voting_category_avgs = cached_data&.dig(:category_avgs) || {}
    end

    def load_ysws_review_stats
      cached_data = Rails.cache.fetch("super_mega_ysws_review", expires_in: 1.hour) do
        begin
          # Build 14-day trend data using EST timezone
          est_timezone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
          ysws_review_graph_data = {
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

            ysws_review_graph_data[:done][date.to_s] = done_count
            ysws_review_graph_data[:returned][date.to_s] = returned_count
          end

          # Calculate summary stats using EST dates
          today_est = Time.current.in_time_zone(est_timezone).to_date
          week_ago_est = 7.days.ago.in_time_zone(est_timezone).to_date

          done_total = ysws_review_graph_data[:done].values.sum
          returned_total = ysws_review_graph_data[:returned].values.sum

          ysws_review_stats = {
            total: done_total + returned_total,
            done_total: done_total,
            returned_total: returned_total,
            today: (ysws_review_graph_data[:done][today_est.to_s] || 0) + (ysws_review_graph_data[:returned][today_est.to_s] || 0),
            this_week: (ysws_review_graph_data[:done].select { |date, _| Date.parse(date) >= week_ago_est }.sum { |_, count| count }) +
                       (ysws_review_graph_data[:returned].select { |date, _| Date.parse(date) >= week_ago_est }.sum { |_, count| count })
          }

          { graph_data: ysws_review_graph_data, stats: ysws_review_stats }
        rescue StandardError => e
          Rails.logger.error "[SuperMegaDashboard] Error loading YSWS review stats: #{e.message}"
          Rails.logger.error "[SuperMegaDashboard] Backtrace: #{e.backtrace.first(5).join("\n")}"
          { graph_data: nil, stats: { error: e.message } }
        end
      end

      @ysws_review_graph_data = cached_data&.dig(:graph_data)
      @ysws_review_stats = cached_data&.dig(:stats) || { error: "Unable to load YSWS data" }
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

      # Calculate ECDF data for devlogs distribution
      # Fetch done reviews
      response_data_done = YswsReviewService.fetch_all_reviews(status: "done")
      reviews_data_done = if response_data_done.is_a?(Hash)
        response_data_done["reviews"] || response_data_done[:reviews] || []
      elsif response_data_done.is_a?(Array)
        response_data_done
      else
        []
      end

      # Extract devlog counts from done reviews
      devlog_counts_done = reviews_data_done.map do |review|
        review["devlogCount"] || review[:devlogCount] || 0
      end.compact

      # Fetch all reviews (no status filter)
      response_data_all = YswsReviewService.fetch_all_reviews
      reviews_data_all = if response_data_all.is_a?(Hash)
        response_data_all["reviews"] || response_data_all[:reviews] || []
      elsif response_data_all.is_a?(Array)
        response_data_all
      else
        []
      end

      # Extract devlog counts from all reviews
      devlog_counts_all = reviews_data_all.map do |review|
        review["devlogCount"] || review[:devlogCount] || 0
      end.compact

      # Calculate ECDF for both datasets
      @ysws_review_ecdf_data = {
        done: calculate_ecdf(devlog_counts_done),
        all: calculate_ecdf(devlog_counts_all)
      }
    rescue StandardError => e
      Rails.logger.error "[SuperMegaDashboard] Error loading YSWS review stats: #{e.message}"
      Rails.logger.error "[SuperMegaDashboard] Backtrace: #{e.backtrace.first(5).join("\n")}"
      @ysws_review_graph_data = nil
      @ysws_review_stats = { error: e.message }
      @ysws_review_ecdf_data = nil
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

    def calculate_ecdf(data)
      return [] if data.empty?

      # Sort the data
      sorted_data = data.sort
      n = sorted_data.size

      # Calculate 99th percentile threshold
      percentile_99_index = [ (n * 0.99).ceil - 1, n - 1 ].min
      percentile_99_value = sorted_data[percentile_99_index]

      # Filter data to only include values up to 99th percentile
      filtered_data = sorted_data.select { |x| x <= percentile_99_value }
      filtered_n = filtered_data.size.to_f

      # Get unique values and calculate cumulative probability for each
      unique_values = filtered_data.uniq.sort

      ecdf_points = unique_values.map do |value|
        # Count how many values are <= current value in filtered data
        count = filtered_data.count { |x| x <= value }
        cumulative_probability = (count / filtered_n * 100).round(2)

        {
          devlogs: value,
          cumulative_percent: cumulative_probability
        }
      end

      ecdf_points
    end
  end
end

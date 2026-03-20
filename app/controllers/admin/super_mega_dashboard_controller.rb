# frozen_string_literal: true

module Admin
  class SuperMegaDashboardController < Admin::ApplicationController
    CACHE_KEYS = %w[
      super_mega_fraud_stats
      super_mega_ban_trend
      super_mega_order_trend
      super_mega_report_trend
      joe_fraud_stats
      super_mega_payouts
      super_mega_fulfillment
      super_mega_fulfillment_trend
      super_mega_order_states_trend
      super_mega_support
      super_mega_support_vibes
      super_mega_support_graph
      super_mega_voting
      super_mega_ysws_review_v2
      super_mega_ship_certs_raw
      sw_vibes_data
    ].freeze

    def index
      authorize :admin, :access_super_mega_dashboard?

      load_fraud_stats
      load_payouts_stats
      load_fulfillment_stats_safely
      load_support_stats
      load_support_vibes_stats
      load_support_graph_data
      load_voting_stats
      load_ysws_review_stats
      load_flavortime_summary
      load_pyramid_scheme_stats
      load_community_engagement_stats
      load_fraud_happiness_data
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

        total_distributed_cookies = LedgerEntry.where("amount > 0").sum(:amount)
        used_cookies = LedgerEntry.where("amount < 0").sum(:amount).abs
        cookie_utilization_percentage = ((used_cookies.to_f / total_distributed_cookies) * 100).round(2)

        total_approved_ysws_db_hours = fetch_approved_ysws_db_hours
        if total_approved_ysws_db_hours > 0
          dollars_per_hour = (total_distributed_cookies / 5) / total_approved_ysws_db_hours
        else
          dollars_per_hour = 0
        end

        {
          payouts_cap: payouts_cap,
          payouts: {
            created: recent_stats[0],
            destroyed: recent_stats[1],
            txns: recent_stats[2],
            volume: recent_stats[3]
          },
          cookie_utilization_percentage: cookie_utilization_percentage,
          dollars_per_hour: dollars_per_hour
        }
      end
      @payouts_cap = cached_data&.dig(:payouts_cap) || 0
      @payouts = cached_data&.dig(:payouts) || { created: 0, destroyed: 0, txns: 0, volume: 0 }

      @dollars_per_hour = cached_data&.dig(:dollars_per_hour) || 0
      @cookie_utilization_percentage = cached_data&.dig(:cookie_utilization_percentage) || 0
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
      @fulfillment_trend_data = build_fulfillment_trend_data
      @order_states_trend_data = build_order_states_trend_data
    end

    def load_fulfillment_stats_safely
      load_fulfillment_stats
    rescue StandardError => e
      Rails.logger.warn("[SuperMegaDashboard] Temporarily disabling fulfillment stats (#{e.class}): #{e.message}")

      blank_stats = {
        pending: "—",
        awaiting: "—",
        total: "—"
      }

      @fulfillment_temporarily_disabled = true
      @fulfillment = {
        all: blank_stats.dup,
        hq_mail: blank_stats.dup,
        third_party: blank_stats.dup,
        warehouse: blank_stats.dup,
        other: blank_stats.dup
      }
      @fulfillment_trend_data = nil
      @order_states_trend_data = nil
    end

    def build_fulfillment_trend_data
      Rails.cache.fetch("super_mega_fulfillment_trend", expires_in: 1.hour) do
        trend_data = {}
        (0..29).reverse_each do |days_ago|
          date = days_ago.days.ago.to_date
          day_range = date.beginning_of_day..date.end_of_day

          fulfilled = ShopOrder.where(fulfilled_at: day_range).count
          created = ShopOrder.real.where(created_at: day_range).count

          trend_data[date.to_s] = { fulfilled: fulfilled, created: created }
        end
        trend_data
      end
    end

    def build_order_states_trend_data
      Rails.cache.fetch("super_mega_order_states_trend", expires_in: 1.hour) do
        trend_data = {}
        (0..29).reverse_each do |days_ago|
          date = days_ago.days.ago.to_date
          day_range = date.beginning_of_day..date.end_of_day

          pending = ShopOrder.real.where(created_at: day_range).count
          awaiting = ShopOrder.where(awaiting_periodical_fulfillment_at: day_range).count
          fulfilled = ShopOrder.where(fulfilled_at: day_range).count
          on_hold = ShopOrder.where(on_hold_at: day_range).count
          closed = fulfilled + ShopOrder.where(rejected_at: day_range).count

          trend_data[date.to_s] = {
            pending: pending,
            awaiting_periodical_fulfillment: awaiting,
            on_hold: on_hold,
            closed: closed
          }
        end
        trend_data
      end
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
          hang_time = data.dig("hang_time", "p95") || {}

          all_dates = (unresolved.keys + hang_time.keys).uniq.sort

          all_dates.map do |date|
            {
              date: date,
              unresolved_tickets: unresolved[date] || 0,
              hang_time_p95: hang_time[date].nil? ? nil : (hang_time[date] / 3600).round(2)
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
        @sw_metrics_history = []
        return
      end

      metrics_history = raw_data["metricsHistory"] || []

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
        new_ships_today: raw_data["newShipsToday"],
        overall_nps_mean: raw_data["overallNpsMean"],
        weekly_nps: raw_data["weeklyNps"] || {},
        all_ticket_feedback: parse_all_ticket_feedback(raw_data["allTicketFeedback"])
      }

      @sw_vibes_history = parse_sw_vibes_history(metrics_history)
      @sw_metrics_history = parse_sw_metrics_history(metrics_history)
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

    def parse_sw_metrics_history(metrics_history)
      metrics_history.filter_map do |entry|
        output = entry["output"] || {}
        next if output["for_date"].present?

        avg_secs = output["avgReviewSecs"]
        next if avg_secs.nil?

        created = entry["createdAt"]
        recorded_at = created.present? ? Time.zone.parse(created) : nil

        OpenStruct.new(
          recorded_at: recorded_at,
          avg_review_secs: avg_secs.to_i,
          p95_review_secs: output["p95ReviewSecs"].to_i,
          active_reviewers: output["activeReviewers"].to_i
        )
      rescue ArgumentError, Date::Error
        nil
      end.sort_by { |e| e.recorded_at || Time.zone.at(0) }.reverse
    end

    def parse_all_ticket_feedback(rows)
      Array(rows).filter_map do |row|
        next unless row.is_a?(Hash)

        created = row["createdAt"]
        OpenStruct.new(
          id: row["id"],
          ticket_id: row["ticketId"],
          rating: row["rating"],
          comment: row["comment"].to_s,
          created_at: created.present? ? Time.zone.parse(created) : nil
        )
      rescue ArgumentError, Date::Error
        nil
      end.sort_by { |f| f.created_at || Time.zone.at(0) }.reverse
    end

    def load_voting_stats
      cached_data = Rails.cache.fetch("super_mega_voting", expires_in: 10.minutes) do
        today = Time.current.beginning_of_day..Time.current.end_of_day
        this_week = 7.days.ago.beginning_of_day..Time.current

        avg_columns = Vote.enabled_categories.map do |category|
          column = Vote.score_column_for!(category)
          "AVG(#{column}) AS avg_#{category}"
        end.join(", ")

        select_core = <<~SQL.squish
          COUNT(*) AS total_votes,
          COUNT(*) FILTER (WHERE created_at >= ? AND created_at <= ?) AS votes_today,
          COUNT(*) FILTER (WHERE created_at >= ?) AS votes_this_week,
          AVG(time_taken_to_vote) AS avg_time,
          COUNT(*) FILTER (WHERE repo_url_clicked = true) AS repo_clicks,
          COUNT(*) FILTER (WHERE demo_url_clicked = true) AS demo_clicks,
          COUNT(*) FILTER (WHERE reason IS NOT NULL AND reason != '') AS with_reason
        SQL
        select_sql = Vote.sanitize_sql_array([
          avg_columns.present? ? "#{select_core}, #{avg_columns}" : select_core,
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
      cached_data = Rails.cache.fetch("super_mega_ysws_review_v2", expires_in: 1.hour) do
        begin
          est_timezone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]

          # Fetch all "done" and "returned" reviews at once (2 API calls total)
          # The API returns ALL reviews with their createdAt timestamps
          done_reviews = YswsReviewService.fetch_all_reviews(status: "done")
          returned_reviews = YswsReviewService.fetch_all_reviews(status: "returned")

          # Extract review arrays
          done_data = extract_reviews(done_reviews)
          returned_data = extract_reviews(returned_reviews)

          # Build 14-day trend by grouping reviews by date CLIENT-SIDE
          ysws_review_graph_data = {
            done: count_reviews_by_date(done_data, est_timezone, 14),
            returned: count_reviews_by_date(returned_data, est_timezone, 14)
          }

          # Calculate summary stats
          today_est = Time.current.in_time_zone(est_timezone).to_date
          week_ago_est = 7.days.ago.in_time_zone(est_timezone).to_date

          done_total = ysws_review_graph_data[:done].values.sum
          returned_total = ysws_review_graph_data[:returned].values.sum

          ysws_review_stats = {
            total: done_total + returned_total,
            done_total: done_total,
            returned_total: returned_total,
            today: (ysws_review_graph_data[:done][today_est.to_s] || 0) +
              (ysws_review_graph_data[:returned][today_est.to_s] || 0),
            this_week: calculate_week_total(ysws_review_graph_data, week_ago_est)
          }

          # ECDF data - reuse the done_data we already have!
          devlog_counts_done = done_data.map { |r| r["devlogCount"] || r[:devlogCount] || 0 }.compact

          # Fetch all reviews for ECDF comparison (3rd API call)
          all_reviews = YswsReviewService.fetch_all_reviews
          all_data = extract_reviews(all_reviews)
          devlog_counts_all = all_data.map { |r| r["devlogCount"] || r[:devlogCount] || 0 }.compact

          ysws_review_ecdf_data = {
            done: calculate_ecdf(devlog_counts_done),
            all: calculate_ecdf(devlog_counts_all)
          }

          # Fetch daily stats for reviewer trend graph
          daily_stats = YswsReviewService.fetch_daily_stats
          ysws_reviewer_trend_data = process_daily_stats(daily_stats, est_timezone, 14)

          { graph_data: ysws_review_graph_data, stats: ysws_review_stats, ecdf_data: ysws_review_ecdf_data, reviewer_trend_data: ysws_reviewer_trend_data }
        rescue StandardError => e
          Rails.logger.error "[SuperMegaDashboard] Error loading YSWS review stats: #{e.message}"
          Rails.logger.error "[SuperMegaDashboard] Backtrace: #{e.backtrace.first(5).join("\n")}"
          { graph_data: nil, stats: { error: e.message }, ecdf_data: nil, reviewer_trend_data: nil }
        end
      end

      @ysws_review_graph_data = cached_data&.dig(:graph_data)
      @ysws_review_stats = cached_data&.dig(:stats) || { error: "Unable to load YSWS data" }
      @ysws_review_ecdf_data = cached_data&.dig(:ecdf_data)
      @ysws_reviewer_trend_data = cached_data&.dig(:reviewer_trend_data)
    end

    def load_community_engagement_stats
      attendance_data = ShowAndTellAttendance.group(:date).count
      last_winner_attendance = ShowAndTellAttendance
                                 .where(winner: true)
                                 .order(date: :desc, updated_at: :desc)
                                 .includes(:project, :user)
                                 .first

      @show_and_tell_stats = {
        attendance_by_date: attendance_data,
        last_winner: last_winner_attendance
      }
    end

    def load_flavortime_summary
      with_dashboard_timing("flavortime") do
        cached_data = Rails.cache.fetch("super_mega_flavortime_summary", expires_in: dashboard_cache_ttl(30.seconds, 2.minutes)) do
          scoped_sessions = FlavortimeSession.all
          platform_counts = grouped_flavortime_counts(scoped_sessions, :platform)
          version_counts = grouped_flavortime_counts(scoped_sessions, :app_version)

          {
            summary: {
              active_users: FlavortimeSession.active_users_count,
              total_users: FlavortimeSession.select(:user_id).distinct.count,
              total_sessions: FlavortimeSession.count,
              status_hours: (FlavortimeSession.sum(:discord_status_seconds).to_f / 3600).round(1),
              sessions_by_platform: compact_flavortime_breakdown(platform_counts),
              sessions_by_version: compact_flavortime_breakdown(version_counts),
              activity_chart: build_flavortime_activity_chart(scoped_sessions)
            },
            slack_ids: FlavortimeSession
              .joins(:user)
              .where.not(users: { slack_id: [ nil, "" ] })
              .distinct
              .pluck("users.slack_id")
          }
        end

        @flavortime_summary = empty_flavortime_summary.merge(cached_data.fetch(:summary, {}))
        @flavortime_slack_ids = Array(cached_data.fetch(:slack_ids, []))
      end
    rescue StandardError => e
      Rails.logger.warn("[SuperMegaDashboard] Flavortime section unavailable (#{e.class}): #{e.message}")
      @flavortime_summary = empty_flavortime_summary.merge(error: "Flavortime data is temporarily unavailable")
      @flavortime_slack_ids = []
    end

    def load_pyramid_scheme_stats
      payload = with_dashboard_timing("pyramid_scheme") do
        Rails.cache.fetch("super_mega_pyramid_scheme_stats_v2", expires_in: dashboard_cache_ttl(30.seconds, 5.minutes)) do
          PyramidReferralService.fetch_dashboard_stats
        end
      end

      if payload.blank? || payload["error"].present?
        @pyramid_scheme_stats = { error: payload&.dig("error") || "Pyramid dashboard stats are unavailable" }
        return
      end

      overlap_count = ((payload.dig("activity", "user_slack_ids") || []) & Array(@flavortime_slack_ids)).count

      @pyramid_scheme_stats = {
        total_hours_logged: payload.dig("activity", "total_hours_logged") || 0,
        total_users: payload.dig("activity", "all_users") || 0,
        total_referrals_verified: (payload.dig("referrals", "id_verified") || 0) + (payload.dig("referrals", "completed") || 0),
        flavortime_users: overlap_count,
        verified_hours_last_week: payload.dig("activity", "verified_hours_last_week") || 0,
        verified_hours_previous_week: payload.dig("activity", "verified_hours_previous_week") || 0,
        referrals_gained_last_week: payload.dig("activity", "referrals_gained_last_week") || 0,
        referrals_gained_previous_week: payload.dig("activity", "referrals_gained_previous_week") || 0,
        shipped_projects: payload.dig("activity", "shipped_projects") || 0,
        partial_data: payload["partial_data"] == true,
        data_source: payload["data_source"],
        activity_timeline: payload.dig("activity", "timeline") || [],
        referral_chart: {
          labels: [ "Pending", "ID Verified", "Completed" ],
          values: [
            payload.dig("referrals", "pending") || 0,
            payload.dig("referrals", "id_verified") || 0,
            payload.dig("referrals", "completed") || 0
          ]
        },
        poster_chart: {
          labels: [ "Completed Physical", "Digital", "Rejected" ],
          values: [
            payload.dig("posters", "completed_physical") || 0,
            payload.dig("posters", "completed_digital") || 0,
            payload.dig("posters", "rejected_physical") || 0
          ]
        }
      }
    rescue StandardError => e
      Rails.logger.warn("[SuperMegaDashboard] Pyramid section unavailable (#{e.class}): #{e.message}")
      @pyramid_scheme_stats = { error: "Pyramid dashboard stats are temporarily unavailable" }
    end

    def load_fraud_happiness_data
      data = FraudAirtableService.fetch_fraud_happy_by_week || {}
      @fraud_happiness_week = data[:week]
      @fraud_happiness_records = data[:records] || []
      @fraud_happiness_avg_scores = data[:avg_scores] || { total_responses: 0 }
      @fraud_happiness_error = data[:error]
    end

    def extract_reviews(response_data)
      if response_data.is_a?(Hash)
        response_data["reviews"] || response_data[:reviews] || []
      elsif response_data.is_a?(Array)
        response_data
      else
        []
      end
    end

    def count_reviews_by_date(reviews, timezone, num_days)
      counts = {}

      # Initialize all dates with 0
      (0...num_days).each do |days_ago|
        date = days_ago.days.ago.in_time_zone(timezone).to_date
        counts[date.to_s] = 0
      end

      # Count reviews by grouping their createdAt dates
      reviews.each do |review|
        created_at_str = review["createdAt"] || review[:createdAt]
        next unless created_at_str

        created_date = Time.parse(created_at_str).in_time_zone(timezone).to_date
        counts[created_date.to_s] += 1 if counts.key?(created_date.to_s)
      end

      counts
    end

    def calculate_week_total(graph_data, week_ago_date)
      [ :done, :returned ].sum do |status|
        graph_data[status].select { |date, _| Date.parse(date) >= week_ago_date }.sum { |_, count| count }
      end
    end

    def grouped_flavortime_counts(scope, column)
      scope
        .group(Arel.sql("COALESCE(NULLIF(#{column}, ''), 'unknown')"))
        .order(Arel.sql("COUNT(*) DESC"))
        .count
    end

    def build_flavortime_activity_chart(scope)
      date_range = 13.days.ago.to_date..Time.current.to_date
      sessions_by_day = scope
        .where(created_at: date_range.first.beginning_of_day..date_range.last.end_of_day)
        .group(Arel.sql("DATE(created_at)"))
        .count
      status_hours_by_day = scope
        .where(created_at: date_range.first.beginning_of_day..date_range.last.end_of_day)
        .group(Arel.sql("DATE(created_at)"))
        .sum(:discord_status_seconds)

      {
        labels: date_range.map { |date| date.strftime("%b %-d") },
        sessions: date_range.map { |date| sessions_by_day[date] || 0 },
        status_hours: date_range.map { |date| ((status_hours_by_day[date] || 0).to_f / 3600).round(1) }
      }
    end

    def empty_flavortime_summary
      {
        active_users: 0,
        total_users: 0,
        total_sessions: 0,
        status_hours: 0,
        sessions_by_platform: {},
        sessions_by_version: {},
        activity_chart: {
          labels: [],
          sessions: [],
          status_hours: []
        }
      }
    end

    def compact_flavortime_breakdown(counts, limit: 5)
      return {} if counts.blank?

      top_counts = counts.to_a.first(limit)
      remaining_count = counts.to_a.drop(limit).sum { |(_, count)| count }

      chart_data = top_counts.to_h
      chart_data["other"] = remaining_count if remaining_count.positive?
      chart_data
    end

    def dashboard_cache_ttl(development_ttl, production_ttl)
      Rails.env.development? ? development_ttl : production_ttl
    end

    def with_dashboard_timing(section_name)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(1)
      Rails.logger.info("[SuperMegaDashboard] #{section_name} loaded in #{elapsed_ms}ms")
      result
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

    def process_daily_stats(daily_stats, timezone, num_days)
      return nil if daily_stats.blank?

      # Get the last num_days dates
      dates = (0...num_days).map { |days_ago| days_ago.days.ago.in_time_zone(timezone).to_date.to_s }.reverse

      # Initialize data structure
      reviewer_data = {}
      total_by_date = {}

      # Process each day's data
      daily_stats.each do |day_stat|
        date = day_stat["date"] || day_stat[:date]
        next unless dates.include?(date)

        total_by_date[date] = day_stat["devlogtotal"] || day_stat[:devlogtotal] || 0
        leaderboard = day_stat["leaderboard"] || day_stat[:leaderboard] || []

        leaderboard.each do |reviewer|
          reviewer_id = reviewer["reviewerId"] || reviewer[:reviewerId]
          username = reviewer["username"] || reviewer[:username]
          devlog_count = reviewer["devlogCount"] || reviewer[:devlogCount] || 0

          reviewer_data[reviewer_id] ||= { username: username, counts: {} }
          reviewer_data[reviewer_id][:counts][date] = devlog_count
        end
      end

      # Fill in missing dates with 0 for all reviewers
      dates.each do |date|
        total_by_date[date] ||= 0
        reviewer_data.each do |reviewer_id, data|
          data[:counts][date] ||= 0
        end
      end

      {
        dates: dates,
        reviewers: reviewer_data,
        totals: total_by_date
      }
    end

    private

    def fetch_approved_ysws_db_hours
      api_key = ENV["UNIFIED_DB_INTEGRATION_AIRTABLE_KEY"]

      table = Norairrecord.table(api_key, "app3A5kJwYqxMLOgh", "YSWS Programs")
      record = table.all(filter: "{Name} = 'Flavortown'").first

      weighted_total = record&.fields&.dig("Weighted–Total")

      weighted_total.to_f * 10
    rescue StandardError => e
      Rails.logger.error("[SuperMegaDashboard] Error fetching approved YSWS hours: #{e.class} - #{e.message}")
      0
    end
  end
end

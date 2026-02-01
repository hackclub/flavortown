# frozen_string_literal: true

module Admin
  class SuperMegaDashboardController < Admin::ApplicationController
    def index
      authorize :admin, :access_super_mega_dashboard?

      load_fraud_stats
      load_payouts_stats
      load_fulfillment_stats
      load_support_stats
      load_ship_certs_stats
      load_voting_stats
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
      response = Faraday.get("https://flavortown.nephthys.hackclub.com/api/stats")
      data = JSON.parse(response.body)

      @support = {
        total: data["total_tickets"],
        open: data["total_open"],
        in_progress: data["total_in_progress"],
        closed: data["total_closed"],
        avg_hang_time: data["average_hang_time_minutes"]&.round,
        resolution_time: data["mean_resolution_time_minutes"]&.round,
        oldest_unanswered: data["oldest_unanswered_ticket_age_minutes"]&.round,
        prev_day: {
          total: data["prev_day_total"],
          open: data["prev_day_open"],
          in_progress: data["prev_day_in_progress"],
          closed: data["prev_day_closed"],
          avg_hang_time: data["prev_day_average_hang_time_minutes"]&.round,
          resolution_time: data["prev_day_mean_resolution_time_minutes"]&.round
        }
      }
    rescue Faraday::Error, JSON::ParserError
      @support = nil
    end

    def load_ship_certs_stats
      conn = Faraday.new do |f|
        f.options.timeout = 5
        f.options.open_timeout = 2
      end

      response = conn.get("https://review.hackclub.com/api/stats/ship-certs") do |req|
        req.headers["x-api-key"] = ENV["SHIPWRIGHTS_API_KEY"]
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
        avg_queue_time: data["avgQueueTime"],
        decisions_today: data["decisionsToday"],
        new_ships_today: data["newShipsToday"]
      }
    rescue Faraday::Error, JSON::ParserError, Faraday::TimeoutError
      @ship_certs = { error: true }
    end

    def load_voting_stats
      today = Time.current.beginning_of_day..Time.current.end_of_day
      this_week = 7.days.ago.beginning_of_day..Time.current

      select_sql = Vote.sanitize_sql_array([
        <<-SQL.squish,
          COUNT(*) AS total_votes,
          COUNT(*) FILTER (WHERE created_at >= ? AND created_at <= ?) AS votes_today,
          COUNT(*) FILTER (WHERE created_at >= ?) AS votes_this_week,
          AVG(time_taken_to_vote) AS avg_time,
          COUNT(*) FILTER (WHERE repo_url_clicked = true) AS repo_clicks,
          COUNT(*) FILTER (WHERE demo_url_clicked = true) AS demo_clicks,
          COUNT(*) FILTER (WHERE reason IS NOT NULL AND reason != '') AS with_reason
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
        column = Vote.score_column_for!(category)
        Vote.where.not(column => nil).average(column)&.round(2)
      end
    end
  end
end

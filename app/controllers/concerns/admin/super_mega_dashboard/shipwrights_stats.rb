# frozen_string_literal: true

module Admin
  module SuperMegaDashboard
    module ShipwrightsStats
      extend ActiveSupport::Concern

      private

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
          approved_per_day: raw_data["approvedPerDay"] || {},
          rejected_per_day: raw_data["rejectedPerDay"] || {},
          rejection_reasons_by_day: raw_data["rejectionReasonsByDay"] || {},
          make_their_day_raw: raw_data["makeTheirDayProjects"] || [],
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

      def load_make_their_day_data
        raw = @ship_certs&.dig(:make_their_day_raw) || []
        return @sw_make_their_day = [] unless raw.any?

        raw = raw.reverse

        project_ids = raw.map { |p| p["ftProjectId"] }.compact
        user_ids    = raw.map { |p| p["requesterFtuid"] }.compact

        projects = Project.where(id: project_ids).index_by { |p| p.id.to_s }
        users    = User.where(id: user_ids).index_by { |u| u.id.to_s }

        @sw_make_their_day = raw.map do |item|
          {
            ft_project_id: item["ftProjectId"],
            ft_user_id:    item["requesterFtuid"],
            project:       projects[item["ftProjectId"].to_s],
            user:          users[item["requesterFtuid"].to_s]
          }
        end
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
    end
  end
end

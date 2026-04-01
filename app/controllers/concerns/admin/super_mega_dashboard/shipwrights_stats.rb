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
    end
  end
end

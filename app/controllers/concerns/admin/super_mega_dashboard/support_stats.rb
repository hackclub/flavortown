# frozen_string_literal: true

module Admin
  module SuperMegaDashboard
    module SupportStats
      extend ActiveSupport::Concern

      private

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

        latest_vibe = @latest_support_vibes
        start_time = latest_vibe&.period_start || 24.hours.ago
        end_time = latest_vibe&.period_end || Time.current

        concerns = @latest_support_vibes&.concerns || []
        additional_data_message_ts = []
        concerns.each do |concern|
          ts = []
          concern["messages"].each do |msg|
            ts << msg["message_ts"] if msg["message_ts"].present?
          end
          additional_data_message_ts << ts
        end

        @additional_concern_data = get_additional_data_for_message_ts(start_time, end_time, additional_data_message_ts)
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

      private

      def get_additional_data_for_message_ts(start_time, end_time, message_ts_array)
        response = nephthys_conn.get("/api/tickets") do |req|
          req.params["after"] = start_time.iso8601
          req.params["before"] = end_time.iso8601
        end

        tickets = JSON.parse(response.body)

        additional_data = message_ts_array.map do |ts_array|
          ts_array.map do |ts|
            ticket = tickets.find { |t| t["message_ts"].to_s.strip == ts.to_s.strip }
            if ticket
              [
                ticket["status"],
                ticket.dig("opened_by", "username"),
                ticket["created_at"],
                ticket["closed_at"]
              ]
            else
              [ nil, nil, nil, nil ]
            end
          end
        end

        additional_data
      end

      def nephthys_conn
        @nephthys_conn ||= Faraday.new("https://flavortown.nephthys.hackclub.com") do |f|
          f.request :retry, max: 2, interval: 0.2, interval_randomness: 0.1, backoff_factor: 2
          f.options.open_timeout = 3
          f.options.timeout = 7
          f.response :raise_error
          f.adapter Faraday.default_adapter
        end
      end
    end
  end
end

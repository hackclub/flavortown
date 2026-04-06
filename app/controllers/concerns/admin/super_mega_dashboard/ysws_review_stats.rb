# frozen_string_literal: true

module Admin
  module SuperMegaDashboard
    module YswsReviewStats
      extend ActiveSupport::Concern

      private

      def load_ysws_review_stats
        cached_data = Rails.cache.fetch("super_mega_ysws_review_v2", expires_in: 1.hour) do
          begin
            est_timezone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]

            done_reviews = YswsReviewService.fetch_all_reviews(status: "done")
            returned_reviews = YswsReviewService.fetch_all_reviews(status: "returned")

            done_data = extract_reviews(done_reviews)
            returned_data = extract_reviews(returned_reviews)

            ysws_review_graph_data = {
              done: count_reviews_by_date(done_data, est_timezone, 14),
              returned: count_reviews_by_date(returned_data, est_timezone, 14)
            }

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

            devlog_counts_done = done_data.map { |r| r["devlogCount"] || r[:devlogCount] || 0 }.compact

            all_reviews = YswsReviewService.fetch_all_reviews
            all_data = extract_reviews(all_reviews)
            devlog_counts_all = all_data.map { |r| r["devlogCount"] || r[:devlogCount] || 0 }.compact

            ysws_review_ecdf_data = {
              done: calculate_ecdf(devlog_counts_done),
              all: calculate_ecdf(devlog_counts_all)
            }

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

        (0...num_days).each do |days_ago|
          date = days_ago.days.ago.in_time_zone(timezone).to_date
          counts[date.to_s] = 0
        end

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

      def calculate_ecdf(data)
        return [] if data.empty?

        sorted_data = data.sort
        n = sorted_data.size

        percentile_99_index = [ (n * 0.99).ceil - 1, n - 1 ].min
        percentile_99_value = sorted_data[percentile_99_index]

        filtered_data = sorted_data.select { |x| x <= percentile_99_value }
        filtered_n = filtered_data.size.to_f

        unique_values = filtered_data.uniq.sort

        unique_values.map do |value|
          count = filtered_data.count { |x| x <= value }
          cumulative_probability = (count / filtered_n * 100).round(2)

          {
            devlogs: value,
            cumulative_percent: cumulative_probability
          }
        end
      end

      def process_daily_stats(daily_stats, timezone, num_days)
        return nil if daily_stats.blank?

        dates = (0...num_days).map { |days_ago| days_ago.days.ago.in_time_zone(timezone).to_date.to_s }.reverse

        reviewer_data = {}
        total_by_date = {}

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
    end
  end
end

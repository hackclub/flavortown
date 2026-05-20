module Helper
  class VotingDashboardController < ApplicationController
    LEADERBOARD_START_DATE = "2026-05-08"

    def index
      authorize :helper, :access_voting_dashboard?

      today     = Time.current.beginning_of_day..Time.current.end_of_day
      this_week = 7.days.ago.beginning_of_day..Time.current

      @overview = {
        total:      Vote.count,
        today:      Vote.where(created_at: today).count,
        this_week:  Vote.where(created_at: this_week).count
      }

      @leaderboard = ActiveRecord::Base.connection.select_all(<<~SQL)
        SELECT
          ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS rank,
          u.display_name AS name,
          COUNT(*) AS vote_count
        FROM votes v
        JOIN users u ON u.id = v.user_id
        JOIN flipper_gates fg
          ON fg.feature_key = 'vote_balance_override'
          AND fg.key = 'actors'
          AND fg.value = CONCAT('User;', u.id)
        WHERE v.created_at >= DATE '#{LEADERBOARD_START_DATE}'
        GROUP BY u.display_name
        ORDER BY vote_count DESC
      SQL
    end
  end
end

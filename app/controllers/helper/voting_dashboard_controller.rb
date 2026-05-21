module Helper
  class VotingDashboardController < ApplicationController
    LEADERBOARD_START_DATE = "2026-05-08"

    def index
      authorize :helper, :access_voting_dashboard?

      now       = Time.current
      today     = now.beginning_of_day..now.end_of_day
      this_week = now.beginning_of_week..now

      threshold = Post::ShipEvent::VOTES_TO_LEAVE_POOL

      full_ship_ids = Vote.payout_countable
        .group(:ship_event_id)
        .having("COUNT(*) >= ?", threshold)
        .select(:ship_event_id)

      ships_in_pool = Post::ShipEvent
        .current_voting_scale
        .where(certification_status: "approved", payout: nil)
        .where.not(id: full_ship_ids)

      ships_in_pool_count = ships_in_pool.count
      votes_cast_on_pool  = Vote.payout_countable.where(ship_event_id: ships_in_pool.select(:id)).count
      votes_remaining     = (ships_in_pool_count * threshold) - votes_cast_on_pool

      @overview = {
        total:              Vote.count,
        today:              Vote.where(created_at: today).count,
        this_week:          Vote.where(created_at: this_week).count,
        ships_in_pool:      ships_in_pool_count,
        votes_remaining:    votes_remaining
      }

      @leaderboard_start_date = Date.parse(LEADERBOARD_START_DATE)

      @leaderboard = ActiveRecord::Base.connection.select_all(<<~SQL)
        SELECT
          ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS rank,
          u.id AS user_id,
          u.display_name AS name,
          COUNT(*) AS vote_count
        FROM votes v
        JOIN users u ON u.id = v.user_id
        JOIN flipper_gates fg
          ON fg.feature_key = 'vote_balance_override'
          AND fg.key = 'actors'
          AND fg.value = CONCAT('User;', u.id)
        WHERE v.created_at >= DATE '#{LEADERBOARD_START_DATE}'
        GROUP BY u.id, u.display_name
        ORDER BY vote_count DESC
      SQL
    end
  end
end

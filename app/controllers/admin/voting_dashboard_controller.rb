module Admin
  class VotingDashboardController < Admin::ApplicationController
    DAYS = %w[Sun Mon Tue Wed Thu Fri Sat].freeze

    def index
      authorize :admin, :access_voting_dashboard?

      today     = Time.current.beginning_of_day..Time.current.end_of_day
      this_week = 7.days.ago.beginning_of_day..Time.current

      select_sql = Vote.sanitize_sql_array([
        <<-SQL.squish,
          COUNT(*) AS total_votes,
          COUNT(*) FILTER (WHERE votes.suspicious = false) AS legitimate_votes,
          COUNT(*) FILTER (WHERE votes.created_at >= ? AND votes.created_at <= ?) AS votes_today,
          COUNT(*) FILTER (WHERE votes.created_at >= ? AND votes.created_at <= ? AND votes.suspicious = false) AS legitimate_votes_today,
          COUNT(*) FILTER (WHERE votes.created_at >= ?) AS votes_this_week,
          COUNT(*) FILTER (WHERE votes.created_at >= ? AND votes.suspicious = false) AS legitimate_votes_this_week,
          AVG(votes.time_taken_to_vote) FILTER (WHERE votes.suspicious = false) AS avg_time,
          COUNT(*) FILTER (WHERE votes.suspicious = false AND votes.repo_url_clicked = true) AS repo_clicks,
          COUNT(*) FILTER (WHERE votes.suspicious = false AND votes.demo_url_clicked = true) AS demo_clicks,
          COUNT(*) FILTER (WHERE votes.suspicious = false AND votes.reason IS NOT NULL AND votes.reason != '') AS with_reason
        SQL
        today.begin, today.end, today.begin, today.end, this_week.begin, this_week.begin
      ])

      vote_stats      = votes_scope.select(select_sql).take
      legitimate_total = vote_stats.legitimate_votes.to_i

      current_scale_ships = Post::ShipEvent.current_voting_scale
      paid_ships   = Post::ShipEvent.where.not(payout: nil).count
      unpaid = current_scale_ships.where(certification_status: "approved", payout: nil)
      unpaid_ships = unpaid.count
      unpaid_ships_without_bugs = unpaid.count { |s| s.hours > 0 }
      unpaid_ships_negative_balance = unpaid.joins(post: :user).where("users.vote_balance < 0").count

      @overview = {
        total:                 vote_stats.total_votes.to_i,
        legitimate_total:      legitimate_total,
        today:                 vote_stats.votes_today.to_i,
        legitimate_today:      vote_stats.legitimate_votes_today.to_i,
        this_week:             vote_stats.votes_this_week.to_i,
        legitimate_this_week:  vote_stats.legitimate_votes_this_week.to_i,
        avg_time_seconds:      vote_stats.avg_time&.round,
        repo_click_rate:       legitimate_total > 0 ? (vote_stats.repo_clicks.to_f / legitimate_total * 100).round(1) : 0,
        demo_click_rate:       legitimate_total > 0 ? (vote_stats.demo_clicks.to_f / legitimate_total * 100).round(1) : 0,
        reason_rate:           legitimate_total > 0 ? (vote_stats.with_reason.to_f / legitimate_total * 100).round(1) : 0,
        paid_ships:                       paid_ships,
        unpaid_ships:                     unpaid_ships,
        unpaid_ships_without_bugs:        unpaid_ships_without_bugs,
        unpaid_ships_negative_balance:    unpaid_ships_negative_balance
      }

      @suspicious_stats = calculate_suspicious_stats
      @category_stats   = calculate_category_stats

      @top_voters = User
        .joins(votes: :ship_event)
        .where(post_ship_events: { voting_scale_version: Post::ShipEvent::CURRENT_VOTING_SCALE_VERSION })
        .group("users.id")
        .select("users.id, users.display_name, COUNT(votes.id) AS votes_count")
        .having("COUNT(votes.id) > 0")
        .order("votes_count DESC")
        .limit(10)

      @most_voted_projects = Project
        .joins(votes: :ship_event)
        .where(deleted_at: nil)
        .where(votes: { suspicious: false })
        .where(post_ship_events: { voting_scale_version: Post::ShipEvent::CURRENT_VOTING_SCALE_VERSION })
        .group("projects.id")
        .select("projects.id, projects.title, COUNT(votes.id) AS votes_count")
        .order("votes_count DESC")
        .limit(10)

      empty_30_days = (30.days.ago.to_date..Date.current).index_with(0)
      daily_counts  = ->(scope) {
        empty_30_days.merge(
          scope.where(created_at: 30.days.ago..).group("DATE(votes.created_at)").count.transform_keys(&:to_date)
        )
      }

      @daily_votes            = daily_counts.call(votes_scope.legitimate)
      @daily_suspicious_votes = daily_counts.call(votes_scope.suspicious)

      @time_distribution = calculate_time_distribution

      @hourly_distribution = votes_scope.legitimate
        .group("EXTRACT(HOUR FROM votes.created_at)::integer").count
        .transform_keys { |h| format("%02d:00", h) }
        .sort.to_h

      @weekly_distribution = votes_scope.legitimate
        .group("EXTRACT(DOW FROM votes.created_at)::integer").count
        .transform_keys { |dow| DAYS[dow.to_i] }

      @recent_votes = votes_scope.includes(:user, :project)
        .order("votes.created_at DESC").limit(30)
    end

    private

    def votes_scope = Vote.current_voting_scale

    def calculate_category_stats
      Vote.enabled_categories.index_with do |category|
        column = Vote.score_column_for!(category)
        scope  = votes_scope.legitimate.where.not(column => nil)
        { avg: scope.average(column)&.round(2), distribution: scope.group(column).count }
      end
    end

    def calculate_time_distribution
      buckets = {
        "30s–1m"  => 30...60,
        "1m–2m"   => 60...120,
        "2m–5m"   => 120...300,
        "5m–10m"  => 300...600,
        ">10m"    => 600..
      }
      times = votes_scope.legitimate.where.not(time_taken_to_vote: nil).pluck(:time_taken_to_vote)
      buckets.transform_values { |range| times.count { |t| range.cover?(t) } }
    end

    def calculate_suspicious_stats
      total             = votes_scope.count
      suspicious        = votes_scope.suspicious.count
      suspicious_week   = votes_scope.suspicious.where(created_at: 7.days.ago.beginning_of_day..).count
      {
        total_suspicious:       suspicious,
        suspicious_percentage:  total > 0 ? (suspicious.to_f / total * 100).round(2) : 0,
        suspicious_this_week:   suspicious_week
      }
    end
  end
end

module Admin
  class VotingDashboardController < Admin::ApplicationController
    def index
      authorize :admin, :access_voting_dashboard?

      today = Time.current.beginning_of_day..Time.current.end_of_day
      this_week = 7.days.ago.beginning_of_day..Time.current

      select_sql = Vote.sanitize_sql_array([
        <<-SQL.squish,
          COUNT(*) AS total_votes,
          COUNT(*) FILTER (WHERE suspicious = false) AS legitimate_votes,
          COUNT(*) FILTER (WHERE created_at >= ? AND created_at <= ?) AS votes_today,
          COUNT(*) FILTER (WHERE created_at >= ? AND created_at <= ? AND suspicious = false) AS legitimate_votes_today,
          COUNT(*) FILTER (WHERE created_at >= ?) AS votes_this_week,
          COUNT(*) FILTER (WHERE created_at >= ? AND suspicious = false) AS legitimate_votes_this_week,
          AVG(time_taken_to_vote) FILTER (WHERE suspicious = false) AS avg_time,
          COUNT(*) FILTER (WHERE suspicious = false AND repo_url_clicked = true) AS repo_clicks,
          COUNT(*) FILTER (WHERE suspicious = false AND demo_url_clicked = true) AS demo_clicks,
          COUNT(*) FILTER (WHERE suspicious = false AND reason IS NOT NULL AND reason != '') AS with_reason
        SQL
        today.begin, today.end, today.begin, today.end, this_week.begin, this_week.begin
      ])

      vote_stats = Vote.select(select_sql).take

      legitimate_total = vote_stats.legitimate_votes.to_i
      @overview = {
        total: vote_stats.total_votes.to_i,
        legitimate_total: legitimate_total,
        today: vote_stats.votes_today.to_i,
        legitimate_today: vote_stats.legitimate_votes_today.to_i,
        this_week: vote_stats.votes_this_week.to_i,
        legitimate_this_week: vote_stats.legitimate_votes_this_week.to_i,
        avg_time_seconds: vote_stats.avg_time&.round,
        repo_click_rate: legitimate_total > 0 ? (vote_stats.repo_clicks.to_f / legitimate_total * 100).round(1) : 0,
        demo_click_rate: legitimate_total > 0 ? (vote_stats.demo_clicks.to_f / legitimate_total * 100).round(1) : 0,
        reason_rate: legitimate_total > 0 ? (vote_stats.with_reason.to_f / legitimate_total * 100).round(1) : 0
      }

      @suspicious_stats = calculate_suspicious_stats

      @category_stats = calculate_category_stats

      @top_voters = User.where("votes_count > 0")
                        .order(votes_count: :desc)
                        .limit(10)
                        .select(:id, :display_name, :votes_count)

      @most_voted_projects = Project
        .joins(:votes)
        .where(deleted_at: nil)
        .where(votes: { suspicious: false })
        .group("projects.id")
        .select("projects.id, projects.title, COUNT(votes.id) AS votes_count")
        .order("votes_count DESC")
        .limit(10)

      @daily_votes = Vote.legitimate.where(created_at: 30.days.ago..)
                         .group("DATE(created_at)")
                         .count
                         .transform_keys(&:to_date)
                         .sort
                         .to_h

      30.times do |i|
        date = i.days.ago.to_date
        @daily_votes[date] ||= 0
      end
      @daily_votes = @daily_votes.sort.to_h

      @time_distribution = calculate_time_distribution

      @recent_votes = Vote.includes(:user, :project)
                          .order(created_at: :desc)
                          .limit(20)

      @recent_suspicious_votes = Vote.suspicious
                                      .includes(:user, :project)
                                      .order(created_at: :desc)
                                      .limit(20)

      @hourly_distribution = Vote.legitimate.group("EXTRACT(HOUR FROM created_at)::integer")
                                 .count
                                 .transform_keys(&:to_i)
                                 .sort
                                 .to_h

      @weekly_distribution = Vote.legitimate.group("EXTRACT(DOW FROM created_at)::integer")
                                 .count
                                 .transform_keys(&:to_i)
    end

    private

    def calculate_category_stats
      stats = {}
      Vote.enabled_categories.each do |category|
        column = Vote.score_column_for!(category)
        avg_score = Vote.legitimate.where.not(column => nil).average(column)

        distribution = Vote.legitimate.where.not(column => nil)
                           .group(column)
                           .count

        stats[category] = {
          avg: avg_score&.round(2),
          distribution: distribution
        }
      end
      stats
    end

    def calculate_time_distribution
      select_sql = Vote.sanitize_sql_array([
        <<-SQL.squish,
          COUNT(*) FILTER (WHERE time_taken_to_vote >= ? AND time_taken_to_vote < ? AND suspicious = false) AS "30s - 1m",
          COUNT(*) FILTER (WHERE time_taken_to_vote >= ? AND time_taken_to_vote < ? AND suspicious = false) AS "1m - 2m",
          COUNT(*) FILTER (WHERE time_taken_to_vote >= ? AND time_taken_to_vote < ? AND suspicious = false) AS "2m - 5m",
          COUNT(*) FILTER (WHERE time_taken_to_vote >= ? AND time_taken_to_vote < ? AND suspicious = false) AS "5m - 10m",
          COUNT(*) FILTER (WHERE time_taken_to_vote >= ? AND suspicious = false) AS "> 10m"
        SQL
        30, 60,
        60, 120,
        120, 300,
        300, 600,
        600
      ])

      Vote.legitimate.where.not(time_taken_to_vote: nil)
          .select(select_sql)
          .take
          .attributes
          .except("id")
    end

    def calculate_suspicious_stats
      total = Vote.count
      suspicious = Vote.suspicious.count
      this_week = 7.days.ago.beginning_of_day..Time.current
      suspicious_this_week = Vote.suspicious.where(created_at: this_week).count

      {
        total_suspicious: suspicious,
        suspicious_percentage: total > 0 ? (suspicious.to_f / total * 100).round(2) : 0,
        suspicious_this_week: suspicious_this_week
      }
    end
  end
end

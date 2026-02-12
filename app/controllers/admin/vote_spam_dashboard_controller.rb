module Admin
  class VoteSpamDashboardController < Admin::ApplicationController
    DEFAULT_MIN_VOTES = 5
    DEFAULT_WINDOW_DAYS = 30
    MAX_ROWS = 200
    RAW_VOTE_LIMIT = 200
    SORT_KEYS = %w[votes f1 f2 f3 f4].freeze
    SORT_DIRECTIONS = %w[asc desc].freeze

    helper_method :sort_link_params, :sort_indicator

    def index
      authorize :admin, :access_vote_spam_dashboard?
      assign_filter_params!

      snapshot = Secrets::VoteSpamDashboardSnapshot.new(
        window_days: @window_days,
        min_votes: @min_votes,
        max_rows: MAX_ROWS,
        sort_key: @sort_key,
        sort_direction: @sort_direction
      ).call
      @rows = snapshot.fetch(:rows)
      @global_table_columns = Secrets::VoteSpamCopy.global_table_columns
    end

    def show
      authorize :admin, :access_vote_spam_dashboard?
      assign_filter_params!

      @show_copy = Secrets::VoteSpamCopy.show_page
      @selected_user_id = params[:user_id].to_i
      @selected_user = User.find_by(id: @selected_user_id)

      unless @selected_user
        redirect_to admin_vote_spam_dashboard_path(window_days: @window_days), alert: "User ##{@selected_user_id} not found."
        return
      end

      drilldown = Secrets::VoteSpamUserDrilldown.new(
        user: @selected_user,
        window_days: @window_days,
        raw_vote_limit: RAW_VOTE_LIMIT
      ).call
      @selected_user_metric = drilldown.fetch(:metric)
      @selected_user_score_series = drilldown.fetch(:score_series)
      @selected_user_average_scores = drilldown.fetch(:average_scores)
      @selected_user_score_distribution = drilldown.fetch(:score_distribution)
      @selected_user_daily_vote_counts = drilldown.fetch(:daily_vote_counts)
      @selected_user_time_taken_series = drilldown.fetch(:time_taken_series)
      @selected_user_vector_distribution = drilldown.fetch(:vector_distribution)
      @selected_user_click_breakdown = drilldown.fetch(:click_breakdown)
      @selected_user_votes = drilldown.fetch(:raw_votes)
    end

    private

    def assign_filter_params!
      min = params[:min_votes].to_i
      @min_votes = min.positive? ? [ min, 1000 ].min : DEFAULT_MIN_VOTES

      days = params[:window_days].to_i
      @window_days = days.positive? ? [ days, 365 ].min : DEFAULT_WINDOW_DAYS

      @sort_key = SORT_KEYS.include?(params[:sort].to_s) ? params[:sort].to_s : "f2"
      @sort_direction = SORT_DIRECTIONS.include?(params[:direction].to_s) ? params[:direction].to_s : "desc"
    end

    def sort_link_params(key)
      next_direction = if @sort_key == key
                         @sort_direction == "asc" ? "desc" : "asc"
      else
                         "desc"
      end

      {
        min_votes: @min_votes,
        window_days: @window_days,
        sort: key,
        direction: next_direction
      }
    end

    def sort_indicator(key)
      return "" unless @sort_key == key

      @sort_direction == "asc" ? " ▲" : " ▼"
    end
  end
end

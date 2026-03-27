module Admin
  class VoteQualityDashboardController < Admin::ApplicationController
    DEFAULT_MIN_VOTES = 5
    DEFAULT_WINDOW_DAYS = 30
    MAX_ROWS = 200
    RAW_VOTE_LIMIT = 200
    SORT_DIRECTIONS = %w[asc desc].freeze

    helper_method :sort_link_params, :sort_indicator

    def index
      authorize :admin, :access_vote_quality_dashboard?
      assign_filter_params!

      snapshot = Secrets::VoteQualityDashboardSnapshot.new(
        window_days: @window_days,
        min_votes: @min_votes,
        max_rows: MAX_ROWS,
        sort_key: @sort_key,
        sort_direction: @sort_direction,
        verdict_filter: @verdict_filter
      ).call
      @rows = snapshot.fetch(:rows)
      @verdict_counts = snapshot.fetch(:verdict_counts)
      @global_table_columns = Secrets::VoteQualityCopy.global_table_columns
      @index_copy = Secrets::VoteQualityCopy.index_page
    end

    def show
      authorize :admin, :access_vote_quality_dashboard?
      assign_filter_params!

      @show_copy = Secrets::VoteQualityCopy.show_page
      @tooltip_copy = Secrets::VoteQualityCopy.index_page
      @chart_bounds = Secrets::VoteQualityCopy.chart_bounds
      @selected_user_id = params[:user_id].to_i
      @selected_user = User.find_by(id: @selected_user_id)

      unless @selected_user
        redirect_to admin_vote_quality_dashboard_path(window_days: @window_days), alert: "User ##{@selected_user_id} not found."
        return
      end

      drilldown = Secrets::VoteQualityUserDrilldown.new(
        user: @selected_user,
        window_days: @window_days,
        raw_vote_limit: RAW_VOTE_LIMIT
      ).call
      @selected_user_metric = drilldown.fetch(:metric)
      @deviation_series = drilldown.fetch(:deviation_series)
      @deviation_by_category = drilldown.fetch(:deviation_by_category)
      @bias_series = drilldown.fetch(:bias_series)
      @selected_user_votes = drilldown.fetch(:raw_votes)
      @medians_by_ship_event = drilldown.fetch(:medians_by_ship_event)
    end

    private

    def assign_filter_params!
      min = params[:min_votes].to_i
      @min_votes = min.positive? ? [ min, 1000 ].min : DEFAULT_MIN_VOTES

      days = params[:window_days].to_i
      @window_days = days.positive? ? [ days, 365 ].min : DEFAULT_WINDOW_DAYS

      @sort_key = Secrets::VoteQualityDashboardSnapshot::VALID_SORT_KEYS.include?(params[:sort].to_s) ? params[:sort].to_s : "quality"
      @sort_direction = SORT_DIRECTIONS.include?(params[:direction].to_s) ? params[:direction].to_s : "asc"
      @verdict_filter = Secrets::VoteQualityDashboardSnapshot::VALID_VERDICT_FILTERS.include?(params[:verdict].to_s) ? params[:verdict].to_s : nil
    end

    def sort_link_params(key)
      next_direction = if @sort_key == key
                         @sort_direction == "asc" ? "desc" : "asc"
      else
                         "desc"
      end

      params = {
        min_votes: @min_votes,
        window_days: @window_days,
        sort: key,
        direction: next_direction
      }
      params[:verdict] = @verdict_filter if @verdict_filter
      params
    end

    def sort_indicator(key)
      return "" unless @sort_key == key

      @sort_direction == "asc" ? " ▲" : " ▼"
    end
  end
end

module Admin
  class FlavortimeDashboardController < Admin::ApplicationController
    RANGE_OPTIONS = {
      "15m" => 15.minutes,
      "1h" => 1.hour,
      "6h" => 6.hours,
      "24h" => 24.hours,
      "7d" => 7.days,
      "30d" => 30.days
    }.freeze

    def index
      authorize :admin, :access_flavortime_dashboard?
      FlavortimeSession.cleanup_expired!

      @selected_range = selected_range
      @from_time, @to_time = selected_time_window

      scoped_sessions = FlavortimeSession.within(@from_time, @to_time)

      @active_users = FlavortimeSession.active_users_count
      @total_unique_users = scoped_sessions.select(:user_id).distinct.count
      @total_sessions = scoped_sessions.count
      @voluntary_closed_sessions = scoped_sessions.where(ended_reason: FlavortimeSession::END_REASON_VOLUNTARY_CLOSE).count
      @timed_out_sessions = scoped_sessions.where(ended_reason: FlavortimeSession::END_REASON_TIMED_OUT).count
      @updated_sessions = scoped_sessions.where(ended_reason: FlavortimeSession::END_REASON_UPDATED).count
      @total_hackatime_corecorded_hours = (scoped_sessions.sum(:discord_shared_seconds).to_f / 3600).round(2)
      @total_status_hours = (scoped_sessions.sum(:discord_status_seconds).to_f / 3600).round(2)
      @sessions_by_platform = grouped_counts(scoped_sessions, :platform)
      @sessions_by_app_version = grouped_counts(scoped_sessions, :app_version)
      @recent_sessions = scoped_sessions.includes(:user).order(created_at: :desc).limit(50)

      @sessions_over_time = grouped_series(scoped_sessions, "COUNT(*)")
      @hackatime_corecorded_hours_over_time = grouped_series(scoped_sessions, "SUM(discord_shared_seconds) / 3600.0")
      @status_hours_over_time = grouped_series(scoped_sessions, "SUM(discord_status_seconds) / 3600.0")
    end

    private

    def selected_range
      value = params[:range].to_s
      return value if RANGE_OPTIONS.key?(value) || value == "all" || value == "custom"

      "30d"
    end

    def selected_time_window
      now = Time.current

      if selected_range == "custom"
        from_value = parse_time_param(params[:from])
        to_value = parse_time_param(params[:to]) || now
        return [ from_value, to_value ]
      end

      if selected_range == "all"
        return [ nil, nil ]
      end

      [ now - RANGE_OPTIONS.fetch(selected_range), now ]
    end

    def parse_time_param(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def grouped_series(scope, aggregate_sql)
      bucket_sql = if hourly_bucket?
        "DATE_TRUNC('hour', created_at)"
      else
        "DATE_TRUNC('day', created_at)"
      end

      rows = scope
        .group(Arel.sql(bucket_sql))
        .order(Arel.sql("#{bucket_sql} ASC"))
        .pluck(Arel.sql(bucket_sql), Arel.sql(aggregate_sql))

      rows.to_h do |time_bucket, value|
        [ time_bucket.in_time_zone, value.to_f.round(2) ]
      end
    end

    def grouped_counts(scope, column)
      scope
        .group(Arel.sql("COALESCE(NULLIF(#{column}, ''), 'unknown')"))
        .order(Arel.sql("COUNT(*) DESC"))
        .count
    end

    def hourly_bucket?
      return true if selected_range.in?(%w[15m 1h 6h 24h custom])

      false
    end
  end
end

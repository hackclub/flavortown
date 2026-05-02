class WrappedPresenter
  # How many recent days to show in the activity-pulse heatmap on the bento.
  ACTIVITY_PULSE_DAYS = 70

  def initialize(user)
    @user = user
  end

  def user
    @user
  end

  # ─── Role helpers (drive optional slide content) ────────────────
  def fraud_dept?
    @user.has_role?(:fraud_dept) || @user.admin?
  end

  def fulfillment_team?
    @user.has_role?(:fulfillment_person) || @user.admin?
  end

  def total_cookies_earned
    @total_cookies_earned ||= positive_entries.sum(:amount)
  end

  def cookies_spent
    @cookies_spent ||= negative_entries.sum(:amount).abs
  end

  def projects_count
    @projects_count ||= @user.projects.count
  end

  def ships_count
    @ships_count ||= @user.projects.where.not(ship_status: "draft").count
  end

  def votes_cast
    @votes_cast ||= @user.votes.count
  end

  def devlogs_count
    @devlogs_count ||= Post.where(user_id: @user.id, postable_type: "Post::Devlog").count
  end

  def coding_seconds
    @coding_seconds ||= Post.where(user_id: @user.id, postable_type: "Post::Devlog")
    .joins("JOIN post_devlogs ON post_devlogs.id = posts.postable_id")
    .where(post_devlogs: { deleted_at: nil })
    .sum("post_devlogs.duration_seconds")
  end

  def coding_hours
    (coding_seconds / 3600.0).round(1)
  end

  # "276h 45m" — human friendly hours+minutes from coding_seconds.
  def coding_hours_minutes_label
    total_minutes = (coding_seconds / 60).to_i
    hours = total_minutes / 60
    minutes = total_minutes % 60
    "#{hours}h #{minutes}m built"
  end

  def shop_orders_count
    @shop_orders_count ||= @user.shop_orders.real.count
  end

  # Returns 0-100 percentile (what % of opt-in users the current user outranks)
  # Returns nil if user has not opted in to the leaderboard
  def leaderboard_percentile
    return nil unless @user.leaderboard_optin?

    Rails.cache.fetch("wrapped_percentile_#{@user.id}", expires_in: 15.minutes) do
      my_balance = @user.ledger_entries.sum(:amount)
      total = User.where(leaderboard_optin: true, banned: false).count
      next nil if total == 0

      below_count = User.where(leaderboard_optin: true, banned: false)
                        .left_joins(:ledger_entries)
                        .group("users.id")
                        .having("COALESCE(SUM(ledger_entries.amount), 0) < ?", my_balance)
                        .count.length

      ((below_count.to_f / total) * 100).round
    end
  end

  # ─── Slide-specific aggregates ───────────────────────────────────

  def reports_filed
    @reports_filed ||= @user.reports.count
  end

  # Org-wide reports the fraud team has handled this season. Surfaced
  # only to fraud_dept users on the reports slide.
  def reports_team_handled
    @reports_team_handled ||= Project::Report.where.not(status: :pending).count
  end

  # Org-wide shop orders the fulfilment team has shipped out this season.
  # Surfaced to fulfillment_person + fraud_dept (admins).
  def orders_team_fulfilled
    @orders_team_fulfilled ||= ShopOrder.where.not(fulfilled_at: nil).count
  end

  def achievements_count
    @achievements_count ||= @user.achievements.count
  end

  def latest_achievement_slug
    @latest_achievement_slug ||= @user.achievements.order(earned_at: :desc).limit(1).pluck(:achievement_slug).first
  end

  # SidequestEntry is project-scoped; pull approved entries through the
  # user's project memberships so each user sees only their own quests.
  def sidequests_completed
    @sidequests_completed ||= SidequestEntry.where(aasm_state: "approved")
                                            .joins(project: :memberships)
                                            .where(memberships: { user_id: @user.id })
                                            .distinct
                                            .count
  end

  # ─────────────────────────────────────────────────────────────────
  # Bento export data — JSON-serialisable summary of the highlights
  # cards. Kept here so the Stimulus controller stays presentational.
  # ─────────────────────────────────────────────────────────────────
  def bento_payload
    {
      total_cookies: total_cookies_earned,
      cookies_spent: cookies_spent,
      hours_label: coding_hours_minutes_label,
      devlogs: devlogs_count,
      ships: ships_count,
      orders: shop_orders_count,
      projects_touched: projects_count,
      active_days: active_days_count,
      tracked_hours: coding_hours,
      top_source: top_source_breakdown,
      activity_pulse: activity_pulse_buckets,
      biggest_gain: biggest_ledger_event(positive: true),
      biggest_spend: biggest_ledger_event(positive: false),
      peak_workday: peak_workday,
      strongest_weekday: strongest_weekday
    }
  end

  private

  def positive_entries
    @user.ledger_entries.where("amount > 0")
  end

  def negative_entries
    @user.ledger_entries.where("amount < 0")
  end

  # Top earning category by `created_by`, plus the share it represents.
  def top_source_breakdown
    totals = positive_entries.group(:created_by).sum(:amount)
    return nil if totals.empty?

    label, amount = totals.max_by { |_, value| value }
    total = totals.values.sum
    {
      label: humanize_ledger_source(label),
      percent: total.zero? ? 0 : ((amount.to_f / total) * 100).round,
      breakdown: totals.sort_by { |_, value| -value }.first(6).map { |key, value|
        { label: humanize_ledger_source(key), amount: value }
      }
    }
  end

  def humanize_ledger_source(raw)
    return "Unknown" if raw.blank?
    raw.to_s.tr("_", " ").split.map(&:capitalize).join(" ")
  end

  # Devlog/coding activity binned per day for the last ACTIVITY_PULSE_DAYS.
  def activity_pulse_buckets
    cutoff = ACTIVITY_PULSE_DAYS.days.ago.to_date
    devlog_counts = Post.where(user_id: @user.id, postable_type: "Post::Devlog")
                        .where("created_at >= ?", cutoff)
                        .group("DATE(created_at)").count

    coding_counts = @user.flavortime_sessions
                         .where("created_at >= ?", cutoff)
                         .group("DATE(created_at)").sum(:discord_shared_seconds)

    (0...ACTIVITY_PULSE_DAYS).map do |offset|
      day = cutoff + offset
      devlogs = devlog_counts[day] || 0
      hours = (coding_counts[day] || 0) / 3600.0
      # Combined intensity score — a devlog counts roughly as one hour.
      devlogs + hours
    end
  end

  def active_days_count
    activity_pulse_buckets.count(&:positive?)
  end

  def biggest_ledger_event(positive:)
    scope = positive ? positive_entries : negative_entries
    entry = positive ? scope.order(amount: :desc).first : scope.order(amount: :asc).first
    return nil unless entry

    { amount: entry.amount.abs, date: entry.created_at.strftime("%b %-d") }
  end

  # Day where the user logged the most coding hours, plus the hours total.
  def peak_workday
    totals = @user.flavortime_sessions.group("DATE(created_at)").sum(:discord_shared_seconds)
    return nil if totals.empty?

    day, seconds = totals.max_by { |_, value| value }
    { date: day.to_date.strftime("%b %-d"), hours: (seconds / 3600.0).round(1) }
  end

  # Weekday on which the user logs the most coding time overall.
  def strongest_weekday
    totals = @user.flavortime_sessions.group("DATE(created_at)").sum(:discord_shared_seconds)
    return nil if totals.empty?

    by_weekday = totals.each_with_object(Hash.new(0)) do |(day, seconds), acc|
      acc[day.to_date.wday] += seconds
    end
    weekday_index, seconds = by_weekday.max_by { |_, value| value }
    {
      label: Date::ABBR_DAYNAMES[weekday_index],
      hours: (seconds / 3600.0).round(1)
    }
  end
end

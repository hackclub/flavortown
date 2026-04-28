class WrappedPresenter
  def initialize(user)
    @user = user
  end

  def total_cookies_earned
    @total_cookies_earned ||= @user.ledger_entries.where("amount > 0").sum(:amount)
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
    @coding_seconds ||= @user.flavortime_sessions.sum(:discord_shared_seconds)
  end

  def coding_hours
    (coding_seconds / 3600.0).round(1)
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
end

class LeaderboardController < ApplicationController
  def index
    scope = User.where(leaderboard_optin: true, banned: false)

    ranked = scope
      .left_joins(:ledger_entries)
      .group(:id)
      .select("users.*, COALESCE(SUM(ledger_entries.amount), 0) AS leaderboard_balance")
      .order("leaderboard_balance DESC, users.id")
    @pagy, @users = pagy(:offset, ranked, count: scope.count, limit: 10)
  end
end

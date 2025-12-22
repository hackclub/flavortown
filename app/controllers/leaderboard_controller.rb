class LeaderboardController < ApplicationController
  def index
    sorted_users = User.where(leaderboard_optin: true).sort_by { |u| -u.cached_balance }
    @pagy, @users = pagy(:offset, sorted_users, limit: 10)
  end
end

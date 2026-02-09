class LeaderboardController < ApplicationController
  def index
    scope = User.where(leaderboard_optin: true, banned: false)

    if current_user&.shadow_banned?
      scope = scope.where(shadow_banned: false).or(scope.where(id: current_user.id))
    else
      scope = scope.where(shadow_banned: false)
    end

    sorted_users = scope.sort_by { |u| -u.cached_balance }
    @pagy, @users = pagy(:offset, sorted_users, limit: 10)
  end
end

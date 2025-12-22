class LeaderboardController < ApplicationController
  def index
    @users = User.where(leaderboard_optin: true)
  end
end

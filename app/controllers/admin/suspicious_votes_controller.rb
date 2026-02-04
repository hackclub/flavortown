module Admin
  class SuspiciousVotesController < Admin::ApplicationController
    def index
      authorize :admin, :access_suspicious_votes?

      @users = User
        .joins(:votes)
        .where(votes: { suspicious: true })
        .group("users.id")
        .select("users.id, users.display_name, COUNT(votes.id) AS suspicious_votes_count")
        .order("suspicious_votes_count DESC")
        .limit(100)
    end
  end
end
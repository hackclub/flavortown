module Admin
  class SuspiciousVotesController < Admin::ApplicationController
    def index
      authorize :admin, :access_suspicious_votes?

      @users = User
        .joins(:votes)
        .where(votes: { suspicious: true })
        .group("users.id")
        .select("users.id, users.display_name, users.voting_locked, COUNT(votes.id) AS suspicious_votes_count")
        .order("suspicious_votes_count DESC")
        .limit(100)

      user_ids = @users.map(&:id)

      raw_timestamps = PaperTrail::Version
        .where(item_type: "User", item_id: user_ids, event: "voting_lock_toggled")
        .group(:item_id)
        .pluck("item_id, MAX(created_at)")
        
      @voting_lock_timestamps = raw_timestamps.each_with_object({}) do |(id, time), hash|
        hash[id.to_i] = time
      end
    end
  end
end
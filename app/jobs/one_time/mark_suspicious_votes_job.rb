module OneTime
  class MarkSuspiciousVotesJob < ApplicationJob
    queue_as :default

    def perform
      mark_suspicious_votes
    end

    private

    def mark_suspicious_votes
      # Find votes from last 7 days that should be marked suspicious
      # Criteria: under 30s OR didn't click both repo and demo links
      suspicious_votes = Vote.where(
        "created_at >= ? AND (time_taken_to_vote < ? OR repo_url_clicked = false OR demo_url_clicked = false) AND suspicious = false",
        7.days.ago.beginning_of_day,
        Vote::SUSPICIOUS_VOTE_THRESHOLD
      )

      count = suspicious_votes.count

      suspicious_votes.find_each do |vote|
        # Use update_columns to bypass callbacks (mark_suspicious_if_fast and after_commit)
        # Recalculations will happen naturally as new legitimate votes come in
        vote.update_columns(suspicious: true)
      end

      Rails.logger.info("OneTime::MarkSuspiciousVotesJob: Marked #{count} votes as suspicious from the last 7 days")
    end
  end
end

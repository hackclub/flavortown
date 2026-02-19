module OneTime
  class MarkSuspiciousVotesJob < ApplicationJob
    queue_as :default

    def perform
      mark_suspicious_votes
    end

    private

    def mark_suspicious_votes
      count = 0
      Vote.where(suspicious: false).find_each do |vote|
        vote.send(:mark_suspicious)
        next unless vote.suspicious?

        vote.update_columns(suspicious: true)
        count += 1
      end

      Rails.logger.info("OneTime::MarkSuspiciousVotesJob: Marked #{count} votes as suspicious")
    end
  end
end

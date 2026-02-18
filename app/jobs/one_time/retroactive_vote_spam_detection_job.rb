module OneTime
  class RetroactiveVoteSpamDetectionJob < ApplicationJob
    queue_as :default

    VOTE_THRESHOLD = Secrets::VoteSpamDetector::SPAM_DETECTION_VOTE_THRESHOLD

    def perform
      spammer_rows = Secrets::VoteSpamMetrics.new(
        vote_scope: Vote.all,
        min_votes: VOTE_THRESHOLD,
        limit: 10_000
      ).call.select { |row| row[:is_spammer] }

      locked_count = 0

      spammer_rows.each do |row|
        user = User.find_by(id: row[:user_id])
        next if user.nil? || user.voting_locked?

        user.lock_voting_and_mark_votes_suspicious!(notify: true)
        locked_count += 1
      end

      Rails.logger.info(
        "OneTime::RetroactiveVoteSpamDetectionJob: " \
        "Found #{spammer_rows.size} spammers, locked #{locked_count} users"
      )
    end
  end
end

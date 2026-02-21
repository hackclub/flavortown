module OneTime
  class RetroactiveVoteSpamDetectionJob < ApplicationJob
    queue_as :default

    VOTE_THRESHOLD = Secrets.available? ? Secrets::VoteSpamDetector::SPAM_DETECTION_VOTE_THRESHOLD : nil
    KARTIKEY_SLACK_ID = "U05F4B48GBF"

    def perform
      to_lock = {}

      spammer_rows = Secrets::VoteSpamMetrics.new(
        vote_scope: Vote.all,
        min_votes: VOTE_THRESHOLD,
        limit: 10_000
      ).call.select { |row| row[:is_spammer] }

      spammer_rows.each do |row|
        user = User.find_by(id: row[:user_id])
        next if user.nil? || user.voting_locked?

        (to_lock[user.id] ||= { user: user, reasons: [] })[:reasons] << :sus_votes
      end

      User.where(banned: true)
          .where("banned_reason ILIKE ?", "%hackatime%")
          .where(voting_locked: false)
          .find_each do |user|
        (to_lock[user.id] ||= { user: user, reasons: [] })[:reasons] << :hackatime
      end

      total_suspicious = 0

      report_lines = to_lock.values.map do |entry|
        user = entry[:user]
        hackatime_banned = entry[:reasons].include?(:hackatime)

        user.lock_voting_and_mark_votes_suspicious!(notify: !hackatime_banned)

        suspicious_count = user.votes.suspicious.count
        total_suspicious += suspicious_count

        reason_label = entry[:reasons].map { |r| r == :sus_votes ? "sus votes" : "hackatime ban" }.join(" + ")
        "• #{user.display_name.presence || user.slack_id} (<@#{user.slack_id}>) — #{suspicious_count} suspicious vote(s) [#{reason_label}]"
      end

      summary = if to_lock.any?
        "Retroactive vote lock complete — #{to_lock.size} user(s) locked, #{total_suspicious} total suspicious vote(s):\n#{report_lines.join("\n")}"
      else
        "Retroactive vote lock complete — no new users needed to be locked."
      end

      SendSlackDmJob.perform_later(KARTIKEY_SLACK_ID, summary)

      Rails.logger.info(
        "OneTime::RetroactiveVoteSpamDetectionJob: " \
        "Found #{spammer_rows.size} spammers, locked #{to_lock.size} users total (#{total_suspicious} suspicious votes)"
      )
    end
  end
end

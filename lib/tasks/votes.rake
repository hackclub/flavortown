namespace :votes do
  desc "Mark suspicious votes from last 7 days (one-time backfill)"
  task mark_suspicious: :environment do
    puts "Starting suspicious votes backfill..."
    OneTime::MarkSuspiciousVotesJob.perform_now
    puts "Done! Check logs for details."
  end
end

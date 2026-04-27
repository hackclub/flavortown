namespace :vote_deficit do
  desc "DM distinct unpaid negative-balance ship owners. Use DRY_RUN=false to send."
  task dm_unpaid_negative_balance: :environment do
    dry_run = ENV.fetch("DRY_RUN", "true") != "false"
    recipients = VoteDeficitHold.notification_recipients.order(:id)
    ship_counts = VoteDeficitHold.unpaid_negative_balance_ship_events
      .joins(:post)
      .group("posts.user_id")
      .count
    held_ship_counts = VoteDeficitHold.ship_events
      .joins(:post)
      .group("posts.user_id")
      .count

    puts "#{dry_run ? '[DRY RUN] ' : ''}Found #{recipients.count} unpaid negative-balance owners to DM."

    recipients.find_each do |user|
      votes_needed = user.vote_balance.abs
      unpaid_ship_count = ship_counts[user.id].to_i
      held_ship_count = held_ship_counts[user.id].to_i

      if dry_run
        puts "Would DM #{user.display_name || user.email || user.id} (slack_id=#{user.slack_id}, vote_balance=#{user.vote_balance}, unpaid_ships=#{unpaid_ship_count}, held_ships=#{held_ship_count})"
        next
      end

      SendSlackDmJob.perform_later(
        user.slack_id,
        nil,
        blocks_path: "notifications/votes/vote_deficit_reminder",
        locals: {
          votes_needed: votes_needed,
          unpaid_ship_count: unpaid_ship_count,
          held_ship_count: held_ship_count
        }
      )

      puts "Queued DM to #{user.display_name || user.email || user.id} (slack_id=#{user.slack_id})"
    end

    puts dry_run ? "Dry run complete. Re-run with DRY_RUN=false to send DMs." : "Done queueing DMs."
  end
end

class VoteDeficitReminderJob < ApplicationJob
  queue_as :default

  THROTTLE_TTL = 24.hours

  def perform(force: false)
    unpaid_ship_counts = VoteDeficitHold.unpaid_negative_balance_ship_events
      .joins(:post)
      .group("posts.user_id")
      .count
    held_ship_counts = VoteDeficitHold.ship_events
      .joins(:post)
      .group("posts.user_id")
      .count

    VoteDeficitHold.held_notification_recipients.find_each do |user|
      next if held_ship_counts[user.id].to_i.zero?
      next if !force && Rails.cache.exist?(cache_key(user))

      SendSlackDmJob.perform_later(
        user.slack_id,
        nil,
        blocks_path: "notifications/votes/vote_deficit_reminder",
        locals: {
          votes_needed: user.vote_balance.abs,
          unpaid_ship_count: unpaid_ship_counts[user.id].to_i,
          held_ship_count: held_ship_counts[user.id].to_i
        }
      )

      Rails.cache.write(cache_key(user), true, expires_in: THROTTLE_TTL)
    end
  end

  private

  def cache_key(user)
    "vote_deficit_reminder:user:#{user.id}"
  end
end

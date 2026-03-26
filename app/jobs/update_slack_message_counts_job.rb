# frozen_string_literal: true

class UpdateSlackMessageCountsJob < ApplicationJob
  queue_as :literally_whenever

  # Update Slack message counts for all users with slack_id
  # Uses a channel-centric approach: fetches each channel's history once
  # and builds counts for all users, rather than querying per-user
  def perform
    Rails.logger.info("Starting Slack message count updates")

    # Reset all counts to 0
    User.where.not(slack_id: nil).update_all(
      flavortown_message_count_14d: 0,
      flavortown_support_message_count_14d: 0
    )

    # Fetch message counts for all users in each channel
    flavortown_counts = SlackMessageCounterService.fetch_all_message_counts(:flavortown, days_back: 14)
    Rails.logger.info("UpdateSlackMessageCountsJob: Flavortown counts: #{flavortown_counts.inspect}")

    support_counts = SlackMessageCounterService.fetch_all_message_counts(:flavortown_support, days_back: 14)
    Rails.logger.info("UpdateSlackMessageCountsJob: Support counts: #{support_counts.inspect}")

    # Update users with their message counts
    update_users_from_counts(flavortown_counts, :flavortown_message_count_14d)
    update_users_from_counts(support_counts, :flavortown_support_message_count_14d)

    # Update the timestamp for all users that were processed
    User.where.not(slack_id: nil).update_all(slack_messages_updated_at: Time.current)

    Rails.logger.info(
      "Completed Slack message count updates: " \
      "#{flavortown_counts.size} users in flavortown, " \
      "#{support_counts.size} users in support"
    )
  rescue StandardError => e
    Rails.logger.error("Failed to update Slack message counts: #{e.message}")
    raise
  end

  private

  def update_users_from_counts(counts_hash, column_name)
    counts_hash.each do |slack_id, count|
      User.where(slack_id: slack_id).update_all(column_name => count)
    end
  end
end

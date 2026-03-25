# frozen_string_literal: true

class UpdateSlackMessageCountsJob < ApplicationJob
  queue_as :literally_whenever

  # Update Slack message counts for all users or a specific user
  # @param user [User, nil] Optional user to update. If nil, updates all users with slack_id
  def perform(user = nil)
    users_to_update = user ? [user] : User.where.not(slack_id: nil)

    users_to_update.find_each do |u|
      update_user_message_counts(u)
    end
  end

  private

  def update_user_message_counts(user)
    return unless user.slack_id.present?

    Rails.logger.info("Updating Slack message counts for user #{user.id} (#{user.email})")

    flavortown_count = SlackMessageCounterService.count_messages(
      user.slack_id,
      :flavortown,
      days_back: 14
    )

    flavortown_support_count = SlackMessageCounterService.count_messages(
      user.slack_id,
      :flavortown_support,
      days_back: 14
    )

    user.update!(
      flavortown_message_count_14d: flavortown_count,
      flavortown_support_message_count_14d: flavortown_support_count,
      slack_messages_updated_at: Time.current
    )

    Rails.logger.info(
      "Updated user #{user.id}: flavortown=#{flavortown_count}, support=#{flavortown_support_count}"
    )
  rescue StandardError => e
    Rails.logger.error(
      "Failed to update Slack message counts for user #{user.id}: #{e.message}"
    )
    # Continue processing other users even if one fails
  end
end

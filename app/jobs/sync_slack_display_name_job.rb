class SyncSlackDisplayNameJob < ApplicationJob
  queue_as :literally_whenever

  def perform(user)
    return unless user.slack_id.present?

    client = Slack::Web::Client.new(token: ENV.fetch("SLACK_BOT_TOKEN", nil))

    begin
      response = client.users_info(user: user.slack_id)
      return unless response.ok

      slack_user = response.user
      profile = slack_user.profile

      new_display_name = profile.display_name.presence || profile.real_name.presence || slack_user.real_name.presence

      if new_display_name.present? && user.display_name != new_display_name
        user.update!(display_name: new_display_name)
      end

    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error("Failed to sync Slack display name for user #{user.id}: #{e.message}")
    end
  end
end

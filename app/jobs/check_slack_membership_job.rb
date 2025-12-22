class CheckSlackMembershipJob < ApplicationJob
  queue_as :literally_whenever

  def perform(user)
    return unless user.slack_id.present?
    return if user.tutorial_step_completed?(:setup_slack)

    client = Slack::Web::Client.new(token: Rails.application.credentials.dig(:slack, :bot_token) || ENV["SLACK_BOT_TOKEN"])

    begin
      response = client.users_info(user: user.slack_id)
      return unless response.ok

      slack_user = response.user
      is_full_member = !slack_user.is_restricted && !slack_user.is_ultra_restricted

      if is_full_member
        user.complete_tutorial_step!(:setup_slack)
        Rails.logger.info("Marked setup_slack tutorial step as complete for user #{user.id} (#{user.slack_id})")
      end
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error("Failed to check Slack membership for user #{user.id}: #{e.message}")
    end
  end
end

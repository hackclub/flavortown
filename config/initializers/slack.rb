Slack.configure do |config|
  config.token = Rails.application.credentials.dig(:slack, :bot_token) || ENV["SLACK_BOT_TOKEN"]
end

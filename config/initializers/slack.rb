Slack.configure do |config|
  config.token = Rails.application.credentials.dig(:slack, :bot_token)
end

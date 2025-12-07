class SendSlackDmJob < ApplicationJob
  queue_as :latency_5m

  def perform(recipient_id, message = nil, blocks_path: nil, locals: {})
    client = Slack::Web::Client.new(token: ENV.fetch("SLACK_BOT_TOKEN", nil))

    recipient = recipient_id.to_s
    channel_id = recipient

    params = { channel: channel_id, as_user: true }

    if blocks_path.present?
      renderer = ApplicationController.renderer.new
      rendered = renderer.render(
        template: blocks_path,
        formats: [ :slack_message ],
        locals: locals
      )
      params.merge!(JSON.parse(rendered, symbolize_names: true))
    end

    params[:text] = message if message.present?

    client.chat_postMessage(**params)
  rescue Slack::Web::Api::Errors::SlackError => e
    Rails.logger.error("Failed to send Slack DM: #{e.message}")
  end
end

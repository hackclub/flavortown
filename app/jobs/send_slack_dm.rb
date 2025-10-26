class SendSlackDmJob < ApplicationJob
    queue_as :latency_5m
    def perform(recipient_id, message = nil, blocks_path: nil)
      client = Slack::Web::Client.new(token: ENV.fetch("SLACK_BOT_TOKEN", nil))

      recipient = recipient_id.to_s
     #   if recipient.start_with?("C", "G", "D")
     #     channel_id = recipient
     #   else
     #     channel_id = Rails.cache.fetch("slack_channel_id_#{recipient}", expires_in: 1.hour) do
     #       response = client.conversations_open(users: recipient)
     #       response.channel.id
     #     end
     #   end
     channel_id = recipient

      params = { channel: channel_id, as_user: true    }
      if blocks_path.present?
        params.merge!(
          JSON.parse(
            render_to_string(template: blocks_path, formats: [ :slack_message ]),
            symbolize_names: true
          )
        )
      end
      params[:text]  = message if message.present?


      client.chat_postMessage(**params)
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error("Failed to send Slack DM: #{e.message}")
      #   Honeybadger.notify(e, context: { recipient_id: recipient_id, message: message, blocks: blocks })
    end
end

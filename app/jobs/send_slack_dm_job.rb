class SendSlackDmJob < ApplicationJob
  queue_as :latency_5m

  def perform(recipient_id, message = nil, blocks_path: nil, locals: {}, thread_ts: nil, sent_by_id: nil)
    record_message(recipient_id, message, blocks_path, sent_by_id)

    if Rails.env.development?
      return
    end

    client = Slack::Web::Client.new(token: Rails.application.credentials.dig(:slack, :bot_token))

    recipient = recipient_id.to_s
    channel_id = recipient

    params = { channel: channel_id, as_user: true }
    params[:thread_ts] = thread_ts if thread_ts.present?

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
    Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
  rescue StandardError => e
    Rails.logger.error("Unexpected error sending Slack DM: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
  end

  private

  def record_message(recipient_id, message, blocks_path, sent_by_id)
    user = User.find_by(slack_id: recipient_id.to_s)
    return unless user
    return if message.blank? && blocks_path.blank?

    PaperTrail.request(whodunnit: sent_by_id&.to_s) do
      Message.create!(
        user: user,
        sent_by_id: sent_by_id,
        content: message,
        block_path: blocks_path
      )
    end
  end
end

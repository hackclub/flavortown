# frozen_string_literal: true

class SlackMessageCounterService
  CHANNEL_IDS = {
    flavortown: "C09MPB8NE8H",
    flavortown_support: "C09MATKQM8C" # flavortown-help channel (support)
  }.freeze

  class << self
    # Count messages from a user in a specific channel within a time period
    # @param slack_id [String] The Slack user ID
    # @param channel_key [Symbol] The channel key from CHANNEL_IDS
    # @param days_back [Integer] Number of days to look back (default: 14)
    # @return [Integer] Count of messages sent by the user
    def count_messages(slack_id, channel_key, days_back: 14)
      return 0 unless slack_id.present?

      channel_id = CHANNEL_IDS[channel_key.to_sym]
      return 0 unless channel_id

      oldest_timestamp = days_back.days.ago.to_i.to_s

      fetch_message_count(slack_id, channel_id, oldest_timestamp)
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error("SlackMessageCounterService: Failed to fetch messages: #{e.message}")
      0
    rescue StandardError => e
      Rails.logger.error("SlackMessageCounterService: Unexpected error: #{e.message}")
      0
    end

    private

    def fetch_message_count(slack_id, channel_id, oldest_timestamp)
      client = Slack::Web::Client.new(token: Rails.application.credentials.dig(:slack, :bot_token))

      message_count = 0
      cursor = nil

      loop do
        response = client.conversations_history(
          channel: channel_id,
          oldest: oldest_timestamp,
          limit: 200,
          cursor: cursor
        )

        break unless response.ok && response.messages.present?

        # Count top-level messages from this user
        message_count += response.messages.count { |msg| msg.user == slack_id && msg.subtype.nil? }

        # Count thread replies from this user
        threaded_messages = response.messages.select { |msg| msg.reply_count.to_i > 0 }
        threaded_messages.each do |msg|
          thread_count = count_thread_replies(client, channel_id, msg.ts, slack_id)
          message_count += thread_count

          # Rate limiting: sleep briefly between thread fetches
          sleep(0.1) if threaded_messages.size > 10
        end

        # Check if there are more pages
        cursor = response.response_metadata&.next_cursor
        break if cursor.blank?

        # Rate limiting: sleep between pages
        sleep(0.5)
      end

      message_count
    end

    def count_thread_replies(client, channel_id, thread_ts, slack_id)
      replies = client.conversations_replies(
        channel: channel_id,
        ts: thread_ts,
        oldest: thread_ts, # Start from thread parent
        limit: 200
      )

      return 0 unless replies.ok && replies.messages.present?

      # Skip first message (parent) and count replies from user
      replies.messages.drop(1).count { |reply| reply.user == slack_id && reply.subtype.nil? }
    end
  end
end

# frozen_string_literal: true

class SlackMessageCounterService
  CHANNEL_IDS = {
    flavortown: "C09MPB8NE8H",
    flavortown_support: "C09MATKQM8C" # flavortown-help channel (support)
  }.freeze

  class << self
    # Fetch message counts for all users in a channel within a time period
    # Returns a hash of {slack_id => count}, or nil if the fetch failed
    # @param channel_key [Symbol] The channel key from CHANNEL_IDS
    # @param days_back [Integer] Number of days to look back (default: 14)
    # @return [Hash, nil] Hash mapping slack_id to message count, or nil on API failure
    def fetch_all_message_counts(channel_key, days_back: 14)
      channel_id = CHANNEL_IDS[channel_key.to_sym]
      return {} unless channel_id

      oldest_timestamp = days_back.days.ago.to_i.to_s

      fetch_channel_message_counts(channel_id, oldest_timestamp)
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error("SlackMessageCounterService: Failed to fetch messages: #{e.message}")
      nil
    rescue StandardError => e
      Rails.logger.error("SlackMessageCounterService: Unexpected error: #{e.message}")
      nil
    end

    private

    def fetch_channel_message_counts(channel_id, oldest_timestamp)
      client = Slack::Web::Client.new(token: Rails.application.credentials.dig(:slack, :bot_token))
      user_counts = Hash.new(0)
      cursor = nil

      Rails.logger.info("SlackMessageCounterService: Fetching message counts for channel #{channel_id}")

      loop do
        response = client.conversations_history(
          channel: channel_id,
          oldest: oldest_timestamp,
          limit: 200,
          cursor: cursor
        )

        break unless response.ok && response.messages.present?

        # Count top-level messages by user
        response.messages.each do |msg|
          if msg.user.present? && msg.subtype.nil?
            user_counts[msg.user] += 1
          end
        end

        # Count thread replies by user
        threaded_messages = response.messages.select { |msg| msg.reply_count.to_i > 0 }
        threaded_messages.each do |msg|
          thread_counts = count_thread_replies_by_user(client, channel_id, msg.ts)
          thread_counts.each do |slack_id, count|
            user_counts[slack_id] += count
          end

          # Rate limiting: sleep briefly between thread fetches
          sleep(0.1) if threaded_messages.size > 10
        end

        # Check if there are more pages
        cursor = response.response_metadata&.next_cursor
        break if cursor.blank?

        # Rate limiting: sleep between pages
        sleep(0.5)
      end

      Rails.logger.info("SlackMessageCounterService: Counted messages for #{user_counts.size} users")
      Rails.logger.info("SlackMessageCounterService: Final user counts hash: #{user_counts.inspect}")
      user_counts
    end

    def count_thread_replies_by_user(client, channel_id, thread_ts)
      replies = client.conversations_replies(
        channel: channel_id,
        ts: thread_ts,
        oldest: thread_ts # Start from thread parent
      )

      return {} unless replies.ok && replies.messages.present?

      # Skip first message (parent) and count all replies by user
      user_counts = Hash.new(0)
      replies.messages.drop(1).each do |reply|
        if reply.user.present? && reply.subtype.nil?
          user_counts[reply.user] += 1
        end
      end
      user_counts
    end
  end
end

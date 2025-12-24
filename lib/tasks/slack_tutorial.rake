# frozen_string_literal: true

namespace :slack_tutorial do
  desc "Check all users and mark setup_slack tutorial step as complete if they are full Slack members"
  task check_and_mark_complete: :environment do
    puts "Checking Slack membership status for all users..."

    total_users = User.count
    checked = 0
    marked_complete = 0
    errors = 0

    User.find_each do |user|
      checked += 1

      # Skip if already completed
      if user.tutorial_step_completed?(:setup_slack)
        puts "User #{user.id} (#{user.slack_id}) already has setup_slack completed, skipping..."
        next
      end

      # Skip if no slack_id
      unless user.slack_id.present?
        puts "User #{user.id} has no slack_id, skipping..."
        next
      end

      begin
        client = Slack::Web::Client.new(token: Rails.application.credentials.dig(:slack, :bot_token) || ENV["SLACK_BOT_TOKEN"])
        response = client.users_info(user: user.slack_id)

        if response.ok
          slack_user = response.user
          is_full_member = !slack_user.is_restricted && !slack_user.is_ultra_restricted

          if is_full_member
            user.complete_tutorial_step!(:setup_slack)
            marked_complete += 1
            puts "✓ User #{user.id} (#{user.slack_id}) is a full Slack member - marked setup_slack as complete"
          else
            puts "✗ User #{user.id} (#{user.slack_id}) is not a full Slack member (guest user)"
          end
        else
          puts "✗ User #{user.id} (#{user.slack_id}): Slack API returned error"
        end
      rescue Slack::Web::Api::Errors::SlackError => e
        errors += 1
        puts "✗ Error checking user #{user.id} (#{user.slack_id}): #{e.message}"
      rescue StandardError => e
        errors += 1
        puts "✗ Error checking user #{user.id} (#{user.slack_id}): #{e.message}"
      end

      # Progress indicator
      if checked % 10 == 0
        puts "Progress: #{checked}/#{total_users} users checked..."
      end
    end

    puts "\n" + "=" * 60
    puts "Summary:"
    puts "  Total users: #{total_users}"
    puts "  Checked: #{checked}"
    puts "  Marked complete: #{marked_complete}"
    puts "  Errors: #{errors}"
    puts "=" * 60
  end
end

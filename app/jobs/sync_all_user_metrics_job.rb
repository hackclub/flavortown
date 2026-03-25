# frozen_string_literal: true

# Orchestrator job that runs all user metrics updates in sequence:
# 1. Updates Slack message counts from Slack API
# 2. Updates project counts from database
# 3. Syncs all metrics to Airtable
#
# Usage:
#   SyncAllUserMetricsJob.perform_later
#   SyncAllUserMetricsJob.perform_later(user) # For a specific user
class SyncAllUserMetricsJob < ApplicationJob
  queue_as :literally_whenever

  # Run all metrics updates in sequence
  # @param user [User, nil] Optional user to update. If nil, updates all users
  def perform(user = nil)
    Rails.logger.info("Starting SyncAllUserMetricsJob#{user ? " for user #{user.id}" : " for all users"}")

    # Step 1: Update Slack message counts (slow - hits Slack API)
    Rails.logger.info("Step 1/3: Updating Slack message counts...")
    UpdateSlackMessageCountsJob.perform_now(user)

    # Step 2: Update project counts (fast - database queries only)
    Rails.logger.info("Step 2/3: Updating project counts...")
    UpdateUserProjectCountsJob.perform_now(user)

    # Step 3: Sync to Airtable (hits Airtable API)
    Rails.logger.info("Step 3/3: Syncing metrics to Airtable...")
    if user
      # For single user, trigger Airtable sync for that user
      # Note: The Airtable job processes in batches, so we just trigger it
      Airtable::UserMetricsSyncJob.perform_now
    else
      # For all users, trigger Airtable sync
      Airtable::UserMetricsSyncJob.perform_now
    end

    Rails.logger.info("SyncAllUserMetricsJob completed successfully")
  rescue StandardError => e
    Rails.logger.error("SyncAllUserMetricsJob failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end

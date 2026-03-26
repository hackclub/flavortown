# frozen_string_literal: true

# Orchestrator job that runs all user metrics updates in sequence:
# 1. Updates Slack message counts from Slack API
# 2. Updates project counts from database
# 3. Syncs all metrics to Airtable
#
# Usage:
#   SyncAllUserMetricsJob.perform_later
class SyncAllUserMetricsJob < ApplicationJob
  queue_as :literally_whenever

  # Run all metrics updates in sequence for all users
  def perform
    Rails.logger.info("Starting SyncAllUserMetricsJob for all users")

    # Step 1: Update Slack message counts (slow - hits Slack API)
    Rails.logger.info("Step 1/3: Updating Slack message counts...")
    UpdateSlackMessageCountsJob.perform_now

    # Step 2: Update project counts (fast - database queries only)
    Rails.logger.info("Step 2/3: Updating project counts...")
    UpdateUserProjectCountsJob.perform_now

    # Step 3: Sync ALL metrics to Airtable (hits Airtable API, loops until complete)
    Rails.logger.info("Step 3/3: Syncing ALL metrics to Airtable...")
    batch_count = 0
    loop do
      Airtable::UserMetricsSyncJob.perform_now
      batch_count += 1

      # Check if there are more records to sync
      remaining = User.where.not(email: [ nil, "" ])
                      .where("metrics_synced_at IS NULL OR metrics_synced_at < updated_at")
                      .count

      Rails.logger.info("  Batch #{batch_count} complete (#{remaining} records remaining)")
      break if remaining.zero?
    end

    Rails.logger.info("SyncAllUserMetricsJob completed successfully (#{batch_count} batches synced)")
  rescue StandardError => e
    Rails.logger.error("SyncAllUserMetricsJob failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end

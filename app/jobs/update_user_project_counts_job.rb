# frozen_string_literal: true

class UpdateUserProjectCountsJob < ApplicationJob
  queue_as :literally_whenever

  # Update project counts for all users using bulk queries
  # Skips validations and callbacks for performance and to handle legacy users
  def perform
    Rails.logger.info("Starting bulk project counts update")

    # Single query to get all counts grouped by user_id
    counts = Project
      .joins(:memberships)
      .where(deleted_at: nil)
      .group("project_memberships.user_id")
      .select(
        "project_memberships.user_id",
        "COUNT(*) as total_count",
        "SUM(CASE WHEN projects.ship_status = 'approved' THEN 1 ELSE 0 END) as shipped_count"
      )

    Rails.logger.info("Fetched counts for #{counts.size} users with projects")

    # Update users in batches using update_all (skips validations/callbacks)
    # This handles legacy users without slack_id or other validation issues
    updated_count = 0
    counts.each_slice(1000) do |batch|
      batch.each do |row|
        User.where(id: row.user_id).update_all(
          projects_count: row.total_count,
          projects_shipped_count: row.shipped_count
        )
        updated_count += 1
      end
    end

    # Also reset counts to 0 for users with no projects
    # Find users who have non-zero counts but aren't in our counts result
    user_ids_with_projects = counts.map(&:user_id)
    zero_count = User
      .where.not(id: user_ids_with_projects)
      .where("projects_count > 0 OR projects_shipped_count > 0")
      .update_all(projects_count: 0, projects_shipped_count: 0)

    Rails.logger.info("Bulk project counts update complete. Updated #{updated_count} users with projects, reset #{zero_count} users to zero.")
  rescue StandardError => e
    Rails.logger.error("Failed to update project counts: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end

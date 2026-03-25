# frozen_string_literal: true

class UpdateUserProjectCountsJob < ApplicationJob
  queue_as :literally_whenever

  # Update project counts for all users or a specific user
  # @param user [User, nil] Optional user to update. If nil, updates all users
  def perform(user = nil)
    users_to_update = user ? [user] : User.all

    users_to_update.find_each do |u|
      update_user_project_counts(u)
    end
  end

  private

  def update_user_project_counts(user)
    Rails.logger.info("Updating project counts for user #{user.id} (#{user.email})")

    # Count total projects (excluding soft-deleted)
    total_projects = user.projects.where(deleted_at: nil).count

    # Count shipped and approved projects
    # ship_status = 'approved' means the project has been reviewed and certified by ship cert
    shipped_projects = user.projects.where(deleted_at: nil, ship_status: "approved").count

    user.update!(
      projects_count: total_projects,
      projects_shipped_count: shipped_projects
    )

    Rails.logger.info(
      "Updated user #{user.id}: total_projects=#{total_projects}, shipped_projects=#{shipped_projects}"
    )
  rescue StandardError => e
    Rails.logger.error(
      "Failed to update project counts for user #{user.id}: #{e.message}"
    )
    # Continue processing other users even if one fails
  end
end

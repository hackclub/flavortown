class OneTime::MigrateUserShadowBansToProjectsJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    users = User.where(shadow_banned: true)

    migrated_users = 0
    migrated_projects = 0
    skipped_projects = 0

    users.find_each do |user|
      reason = user.shadow_banned_reason.presence || "Migrated from user-level shadow ban"

      user.projects.find_each do |project|
        if project.shadow_banned?
          skipped_projects += 1
        else
          project.shadow_ban!(reason: reason)
          migrated_projects += 1
        end
      end

      user.update!(shadow_banned: false, shadow_banned_at: nil, shadow_banned_reason: nil)

      user.dm_user(
        "Hey chef! 🍳 We've updated how moderation works on Flavortown. " \
        "Your account-level shadow ban has been moved to your individual projects instead. " \
        "If you believe any of your projects were flagged in error, please reach out to @Fraud Squad " \
        "or email fraudsquad@hackclub.com and we'll take another look!"
      )

      migrated_users += 1
    end

    Rails.logger.info(
      "[MigrateUserShadowBansToProjects] Complete. " \
      "Migrated #{migrated_users} users, shadow banned #{migrated_projects} projects, " \
      "skipped #{skipped_projects} already-banned projects."
    )
  end
end

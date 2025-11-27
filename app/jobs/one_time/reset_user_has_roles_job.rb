class OneTime::ResetUserHasRolesJob < ApplicationJob
  queue_as :literally_whenever
  def perform
    User.find_each { |u| u.update_column(:has_roles, u.role_assignments.exists?) }
  end
end

# frozen_string_literal: true

class ProjectShowCardComponent < ViewComponent::Base
  attr_reader :project

  def initialize(project:)
    @project = project
  end

  def banner_variant
    return nil unless project.banner.attached?
    project.banner.variant(:card)
  end

#   def followers_count
#     project.memberships_count
#   end

  def devlogs_count
    Post.where(project_id: project.id, postable_type: "Post::Devlog").count
  end

  def has_any_links?
    project.demo_url.present? || project.repo_url.present? || project.readme_url.present?
  end

  def owner_display_name
    owner = project.memberships.includes(:user).owner.first&.user
    owner&.display_name || project.users.first&.display_name || "Unknown"
  end
end

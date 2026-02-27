# frozen_string_literal: true

class VoteProjectShowcaseCardComponent < ViewComponent::Base
  attr_reader :project, :current_user

  def initialize(project:, current_user: nil)
    @project = project
    @current_user = current_user
  end

  def banner_variant
    return nil unless project.banner.attached?

    project.banner.variant(:card)
  end

  def byline_text
    memberships = project.memberships.includes(:user)
    owner_user = memberships.owner.first&.user
    other_users = memberships.where.not(role: :owner).map(&:user).compact
    ordered_users = [ owner_user, *other_users ].compact
    names = ordered_users.map(&:display_name).reject(&:blank?).uniq
    return "" if names.empty?

    "Created by: #{names.map.with_index { |x, i| "<a href=\"/users/#{ordered_users[i].id}\">#{html_escape(x)}</a>" }.join(', ')}".html_safe
  end

  def followers_count
    @followers_count ||= if project.respond_to?(:project_follows_count) && project.has_attribute?(:project_follows_count)
      project.project_follows_count
    else
      project.followers.size
    end
  end

  def show_report_button?
    current_user.present?
  end

  def has_any_links?
    project.demo_url.present? || project.repo_url.present? || project.readme_url.present?
  end

  def report_modal_id
    "vote-project-report-modal-#{project.id}"
  end
end

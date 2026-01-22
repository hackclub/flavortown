# frozen_string_literal: true

class ProjectShowCardComponent < ViewComponent::Base
  attr_reader :project, :current_user

  def initialize(project:, current_user: nil)
    @project = project
    @current_user = current_user
  end

  def owner?
    return false unless current_user

    project.users.include?(current_user)
  end

  def banner_variant
    return nil unless project.banner.attached?
    project.banner.variant(:card)
  end

  #   def followers_count
  #     project.memberships_count
  #   end

  def has_any_links?
    project.demo_url.present? || project.repo_url.present? || project.readme_url.present?
  end

  def followers_count
    @followers_count ||= if project.respond_to?(:project_follows_count) && project.has_attribute?(:project_follows_count)
      project.project_follows_count
    else
      project.followers.size
    end
  end

  def owner_display_name
    owner = project.memberships.includes(:user).owner.first&.user
    owner&.display_name || project.users.first&.display_name || "Unknown"
  end

  def byline_text
    memberships = project.memberships.includes(:user)
    owner_user = memberships.owner.first&.user
    other_users = memberships.where.not(role: :owner).map(&:user).compact
    ordered_users = [ owner_user, *other_users ].compact
    names = ordered_users.map(&:display_name).reject(&:blank?).uniq
    return "" if names.empty?
    "Created by: #{names.join(', ')}"
  end

  def ship_feedback
    return nil if project.draft?

    @ship_feedback ||= ShipCertService.get_feedback(project)
  end

  def ship_status
    return nil if project.draft?

    ship_feedback&.dig(:status) || "pending"
  end

  def ship_status_color
    case ship_status
    when "approved" then "#10b981"
    when "rejected" then "#ef4444"
    else "#fbbf24"
    end
  end

  def ship_status_label
    ship_status&.capitalize || "Pending"
  end

  def ship_feedback_video_url
    ship_feedback&.dig(:video_url)
  end

  def ship_feedback_reason
    ship_feedback&.dig(:reason)
  end

  def has_feedback?
    ship_status.in?(%w[approved rejected]) && (ship_feedback_video_url.present? || ship_feedback_reason.present?)
  end

  def certifier_viewing_others_project?
    current_user&.project_certifier? && !owner?
  end

  def can_view_ai_declaration_details?
    current_user&.admin? || current_user&.fraud_dept?
  end
end

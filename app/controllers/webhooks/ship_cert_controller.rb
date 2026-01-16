class Webhooks::ShipCertController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :enforce_ban
  skip_before_action :refresh_identity_on_portal_return
  before_action :verify_api_key

  def update_status
    Rails.logger.info "Ship cert webhook raw body: #{request.raw_post}"

    body = JSON.parse(request.raw_post)
    project_id = body["id"]
    status = body["status"]
    video_url = body["video_url"]
    reason = body["reason"]
    project_type = body["project_type"]

    Rails.logger.info "Ship cert webhook received: id=#{project_id} status=#{status} project_type=#{project_type}"

    project = Project.find_by(id: project_id)
    unless project
      render json: { error: "Project not found" }, status: :not_found
      return
    end

    ship_event = project.ship_events.first
    unless ship_event.is_a?(Post::ShipEvent)
      render json: { error: "No ship event found" }, status: :not_found
      return
    end

    ship_event.update!(
      certification_status: status,
      feedback_video_url: video_url,
      feedback_reason: reason
    )

    if project_type.present?
      normalized_type = normalize_category(project_type)
      project.update!(project_categories: [ normalized_type ])
    end

    notify_project_owner(project, status, video_url, reason)

    Rails.logger.info "Ship cert webhook: project=#{project_id} status=#{status} project_type=#{project_type}"
    render json: { success: true }
  end

  private

  def notify_project_owner(project, status, video_url, reason)
    return unless %w[approved rejected].include?(status)

    owner = project.memberships.find_by(role: "owner")&.user
    return unless owner&.slack_id

    template = status == "approved" ? "notifications/ship_cert/approved" : "notifications/ship_cert/rejected"

    SendSlackDmJob.perform_later(
      owner.slack_id,
      blocks_path: template,
      locals: { project: project, video_url: video_url, reason: reason }
    )
  end

  def normalize_category(category)
    Project::AVAILABLE_CATEGORIES.include?(category) ? category : "Other"
  end

  def verify_api_key
    api_key = request.headers["x-api-key"]
    expected_key = ENV["SW_DASHBOARD_API_KEY"]

    unless api_key.present? && expected_key.present? && ActiveSupport::SecurityUtils.secure_compare(api_key, expected_key)
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end

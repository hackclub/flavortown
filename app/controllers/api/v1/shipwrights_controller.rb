class Api::V1::ShipwrightsController < Api::BaseController
  skip_before_action :verify_authenticity_token, if: :api_key_present?
  before_action :verify_api_key

  def update_status
    project_id = params[:id]
    status = params[:status]
    video_url = params[:video_url]
    reason = params[:reason]
    project_type = params[:project_type]

    Rails.logger.info "Ship cert update received: id=#{project_id} status=#{status} project_type=#{project_type}"

    project = Project.find_by(id: project_id)
    return render json: { error: "Project not found" }, status: :not_found unless project

    ship_event = project.ship_events.first
    return render json: { error: "No ship event found" }, status: :not_found unless ship_event.is_a?(Post::ShipEvent)

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

    Rails.logger.info "Ship cert updated: project=#{project_id} status=#{status} project_type=#{project_type}"
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

  def api_key_present?
    request.headers["x-api-key"].present?
  end

  def verify_api_key
    api_key = request.headers["x-api-key"]
    expected_key = ENV["SW_DASHBOARD_API_KEY"]

    unless api_key.present? && expected_key.present? && ActiveSupport::SecurityUtils.secure_compare(api_key, expected_key)
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end

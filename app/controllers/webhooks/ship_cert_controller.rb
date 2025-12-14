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

    Rails.logger.info "Ship cert webhook received: id=#{project_id} status=#{status}"

    project = Project.find_by(id: project_id)
    unless project
      render json: { error: "Project not found" }, status: :not_found
      return
    end

    ship_event = project.ship_posts.order(created_at: :desc).first&.postable
    unless ship_event.is_a?(Post::ShipEvent)
      render json: { error: "No ship event found" }, status: :not_found
      return
    end

    ship_event.update!(
      certification_status: status,
      feedback_video_url: video_url,
      feedback_reason: reason
    )

    Rails.logger.info "Ship cert webhook: project=#{project_id} status=#{status}"
    render json: { success: true }
  end

  private

  def verify_api_key
    api_key = request.headers["x-api-key"]
    expected_key = ENV["SW_DASHBOARD_API_KEY"]

    unless api_key.present? && expected_key.present? && ActiveSupport::SecurityUtils.secure_compare(api_key, expected_key)
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end

class Webhooks::MarkSusController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :enforce_ban
  skip_before_action :refresh_identity_on_portal_return
  before_action :verify_api_key
  before_action :load_users

  # POST /webhooks/mark_sus
  # Body: { ft_user_id: "string", user_id: "integer" }
  def mark
    if @target_user.marked_sus_by.include?(@ft_user_id)
      render json: { message: "User already marked sus by this reviewer" }, status: :ok
      return
    end

    PaperTrail.request(whodunnit: @ft_user_id) do
      @target_user.update!(marked_sus_by: @target_user.marked_sus_by + [ @ft_user_id ])
    end

    Rails.logger.info "User #{@target_user.id} (#{@target_user.display_name}) marked sus by ft_user_id=#{@ft_user_id}"
    render json: { success: true, is_sus: true, marked_sus_by: @target_user.marked_sus_by }
  end

  # POST /webhooks/unmark_sus
  # Body: { ft_user_id: "string", user_id: "integer" }
  def unmark
    unless @target_user.marked_sus_by.include?(@ft_user_id)
      render json: { message: "User was not marked sus by this reviewer" }, status: :ok
      return
    end

    PaperTrail.request(whodunnit: @ft_user_id) do
      @target_user.update!(marked_sus_by: @target_user.marked_sus_by - [ @ft_user_id ])
    end

    Rails.logger.info "User #{@target_user.id} (#{@target_user.display_name}) unmarked sus by ft_user_id=#{@ft_user_id}"
    render json: { success: true, is_sus: @target_user.is_sus?, marked_sus_by: @target_user.marked_sus_by }
  end

  private

  def verify_api_key
    api_key = request.headers["x-api-key"]
    expected_key = ENV["SW_DASHBOARD_API_KEY"]

    unless api_key.present? && expected_key.present? && ActiveSupport::SecurityUtils.secure_compare(api_key, expected_key)
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def load_users
    body = JSON.parse(request.raw_post)
    @ft_user_id = body["ft_user_id"].presence
    user_id = body["user_id"]

    unless @ft_user_id.present?
      render json: { error: "ft_user_id is required" }, status: :unprocessable_entity
      return
    end

    unless user_id.present?
      render json: { error: "user_id is required" }, status: :unprocessable_entity
      return
    end

    @marking_user = User.find_by(id: @ft_user_id)
    unless @marking_user&.admin? || @marking_user&.has_role?(:fraud_dept)
      render json: { error: "Forbidden: only admins and fraud department members can mark users as sus" }, status: :forbidden
      return
    end

    @target_user = User.find_by(id: user_id)
    unless @target_user
      render json: { error: "User not found" }, status: :not_found
    end
  end
end

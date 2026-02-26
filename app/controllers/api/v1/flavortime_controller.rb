class Api::V1::FlavortimeController < Api::BaseController
  include ApiAuthenticatable

  def create_session
    FlavortimeSession.cleanup_expired!

    session = FlavortimeSession.start_for!(
      current_api_user,
      session_id: SecureRandom.uuid,
      platform: session_metadata_params[:platform],
      app_version: session_metadata_params[:app_version]
    )

    render json: {
      session_id: session.session_id,
      expires_at: session.expires_at.iso8601,
      active_users: FlavortimeSession.active_users_count
    }, status: :created
  end

  def heartbeat
    FlavortimeSession.cleanup_expired!

    session_id = normalized_session_id
    if session_id.blank?
      return render json: { error: "Session ID is required" }, status: :unprocessable_entity
    end

    session = FlavortimeSession.find_by(user: current_api_user, session_id: session_id)
    unless session
      return render json: { error: "Session ID not found" }, status: :not_found
    end

    session.record_heartbeat!(
      heartbeat_params[:sharing_active_seconds_total],
      platform: session_metadata_params[:platform],
      app_version: session_metadata_params[:app_version]
    )

    render json: {
      active_users: FlavortimeSession.active_users_count,
      expires_at: session.expires_at.iso8601
    }
  end

  def close
    FlavortimeSession.cleanup_expired!

    session_id = normalized_session_id
    if session_id.blank?
      return render json: { error: "Session ID is required" }, status: :unprocessable_entity
    end

    session = FlavortimeSession.find_by(user: current_api_user, session_id: session_id)
    unless session
      return render json: { error: "Session ID not found" }, status: :not_found
    end

    session.close!(
      close_params[:sharing_active_seconds_total],
      platform: session_metadata_params[:platform],
      app_version: session_metadata_params[:app_version]
    )

    render json: {
      active_users: FlavortimeSession.active_users_count,
      closed_at: session.ended_at&.iso8601
    }
  end

  def active_users
    FlavortimeSession.cleanup_expired!
    render json: { active_users: FlavortimeSession.active_users_count }
  end

  private

  def heartbeat_params
    params.permit(:session_id, :sessionId, :sharing_active_seconds_total)
  end

  def close_params
    params.permit(:session_id, :sessionId, :sharing_active_seconds_total)
  end

  def session_metadata_params
    params.permit(:platform, :app_version)
  end

  def normalized_session_id
    value = params[:session_id].presence ||
      params[:sessionId].presence ||
      request.headers["X-Flavortime-Session-Id"].presence

    value&.to_s&.strip&.presence
  end
end

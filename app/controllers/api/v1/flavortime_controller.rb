class Api::V1::FlavortimeController < Api::BaseController
  include ApiAuthenticatable

  def create_fingerprint
    FlavortimeSession.cleanup_expired!

    session = FlavortimeSession.start_for!(
      current_api_user,
      fingerprint: SecureRandom.uuid
    )

    render json: {
      fingerprint: session.fingerprint,
      expires_at: session.expires_at.iso8601,
      active_users: FlavortimeSession.active_users_count
    }, status: :created
  end

  def heartbeat
    FlavortimeSession.cleanup_expired!

    fingerprint = normalized_fingerprint
    if fingerprint.blank?
      return render json: { error: "Fingerprint is required" }, status: :unprocessable_entity
    end

    session = FlavortimeSession.find_by(user: current_api_user, fingerprint: fingerprint)
    unless session
      return render json: { error: "Fingerprint not found" }, status: :not_found
    end

    session.record_heartbeat!(heartbeat_params[:sharing_active_seconds_total])

    render json: {
      active_users: FlavortimeSession.active_users_count,
      expires_at: session.expires_at.iso8601
    }
  end

  def active_users
    FlavortimeSession.cleanup_expired!
    render json: { active_users: FlavortimeSession.active_users_count }
  end

  private

  def heartbeat_params
    params.permit(:fingerprint, :sharing_active_seconds_total)
  end

  def normalized_fingerprint
    value = heartbeat_params[:fingerprint].presence || request.headers["X-Flavortime-Fingerprint"].presence
    value&.to_s&.strip&.presence
  end
end

require "faraday"
require "json"

class KitchenController < ApplicationController
  def index
    authorize :kitchen, :index?

    # temp: Refresh verification_status from HCA and DB
    # TODO: PR to idv
    refresh_verification_status_from_hca!
    current_user.reload

    @has_hackatime_linked = current_user.has_hackatime?
    @has_identity_linked = current_user.identity_verified?
  end

  private

  # temp
  def refresh_verification_status_from_hca!
    identity = current_user.identities.find_by(provider: "hack_club")
    return unless identity&.access_token.present?

    conn = Faraday.new(url: Rails.application.config.identity)
    response = conn.get("/api/v1/me") do |req|
      req.headers["Authorization"] = "Bearer #{identity.access_token}"
      req.headers["Accept"] = "application/json"
    end

    return unless response.success?

    body = JSON.parse(response.body)
    identity_payload = body["identity"] || {}
    latest_status = identity_payload["verification_status"].to_s
    return unless User::VALID_VERIFICATION_STATUSES.include?(latest_status)
    return if current_user.verification_status.to_s == latest_status

    current_user.update!(verification_status: latest_status)
  rescue StandardError => e
    Rails.logger.warn("Kitchen HCA refresh failed: #{e.class}: #{e.message}")
  end
end

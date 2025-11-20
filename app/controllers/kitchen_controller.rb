require "faraday"
require "json"

class KitchenController < ApplicationController
  def index
    redirect_to root_path unless current_user
    return unless current_user

    # temp: Refresh verification_status from HCA and DB
    # TODO: PR to idv
    refresh_verification_status_from_hca!
    current_user.reload

    @has_hackatime_linked = current_user.has_hackatime?
    @has_identity_linked = current_user.identity_verified?
  end

  def hackatime_auth_redirect
    unless current_user
      redirect_to root_path, alert: "Please log in first."
      return
    end

    if current_user.has_hackatime?
      redirect_to kitchen_path, notice: "You're already connected to Hackatime!"
      return
    end

    bypass_keys = ENV.fetch("HACKATIME_BYPASS_KEYS", "").split(",").map(&:strip).reject(&:blank?)
    response = nil
    response_body = nil

    begin
      (bypass_keys.presence || [ nil ]).each do |bypass_key|
        conn = Faraday.new do |f|
          f.request :url_encoded
          f.response :json, parser_options: { symbolize_names: true, rescue_parse_errors: true }
          f.headers["Authorization"] = "Bearer #{Rails.application.credentials.dig(:hackatime, :internal_key)}"
          f.headers["Rack-Attack-Bypass"] = bypass_key if bypass_key.present?
        end

        response = conn.post(
          "https://hackatime.hackclub.com/api/internal/can_i_have_a_magic_link_for/#{current_user.slack_id}",
          {
            email: current_user.email,
            return_data: {
              url: hackatime_sync_url,
              button_text: "Back to Battlemage"
            }
          }
        )
        response_body = response.body
        break unless response.status == 429
      end

      if response.status == 429
        reset_at = response_body.is_a?(Hash) ? response_body[:reset_at] : nil
        msg = "Hackatime is busy, please try again shortly."
        msg += " (after #{reset_at})" if reset_at
        redirect_to kitchen_path, alert: msg
        return
      end

      unless response.success?
        if response_body.is_a?(String) && response_body.strip.start_with?("<!doctype html")
          redirect_to kitchen_path, alert: "Hackatime returned an error page. Try again."
          return
        end
        redirect_to kitchen_path, alert: "Failed to connect to Hackatime. Try again."
        return
      end

      magic_link = response_body.is_a?(Hash) ? response_body[:magic_link] : nil
      if magic_link.blank?
        redirect_to kitchen_path, alert: "Hackatime didn't provide a link. Try again."
        return
      end

      redirect_to magic_link, allow_other_host: true
    rescue Faraday::Error => e
      Rails.logger.error("hackatime connection error: #{e.class} #{e.message}")
      redirect_to kitchen_path, alert: "Could not connect to Hackatime. Try again."
    rescue StandardError => e
      Rails.logger.error("hackatime unexpected error: #{e.class} #{e.message}")
      redirect_to kitchen_path, alert: "Unexpected error. Try again."
    end
  end

  def hackatime_sync
    unless current_user
      redirect_to root_path, alert: "Please log in first."
      return
    end

    slack_uid = current_user.slack_id.to_s
    if slack_uid.blank?
      redirect_to kitchen_path, alert: "Missing Slack ID. Contact support."
      return
    end

    begin
      HackatimeService.sync_user_projects(current_user, slack_uid)
      redirect_to kitchen_path, notice: "Hackatime connected!"
    rescue StandardError => e
      Rails.logger.error("hackatime sync error: #{e.class} #{e.message}")
      redirect_to kitchen_path, alert: "Could not sync Hackatime. Try again."
    end
  end

  private

  # temp
  def refresh_verification_status_from_hca!
    identity = current_user.identities.find_by(provider: "hack_club")
    return unless identity&.access_token.present?

    conn = Faraday.new(url: "https://hca.dinosaurbbq.org")
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

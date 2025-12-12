class IdentitiesController < ApplicationController
  def hackatime
    unless current_user
      redirect_to root_path, alert: "Please log in first."
      return
    end

    auth = request.env["omniauth.auth"]
    access_token = auth&.credentials&.token.to_s

    if access_token.present?
      begin
        conn = Faraday.new(url: "https://hackatime.hackclub.com")
        response = conn.get("/api/v1/authenticated/me") do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Accept"] = "application/json"
        end
        if response.success?
          body = JSON.parse(response.body) rescue {}
          uid = body.dig("id").to_s
        end
      rescue Faraday::Error => e
        Rails.logger.warn("Hackatime /authenticated/me error: #{e.class}: #{e.message}")
      rescue StandardError => e
        Rails.logger.warn("Hackatime /authenticated/me unexpected error: #{e.class}: #{e.message}")
      end
    end

    if uid.blank?
      redirect_to kitchen_path, alert: "Could not determine Hackatime user. Try again."
      return
    end

    identity = current_user.identities.find_or_initialize_by(provider: "hackatime")
    identity.uid = uid
    identity.access_token = access_token if access_token.present?
    identity.save!

    if current_user.tutorial_step_completed?(:setup_hackatime)
      redirect_to kitchen_path, notice: "Hackatime linked!"
    else
      current_user.complete_tutorial_step! :setup_hackatime
      redirect_to kitchen_path(tutorial_dialogue: :setup_hackatime), notice: "Hackatime linked!"
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("Hackatime identity save failed: #{e.record.errors.full_messages.join(", ")}")
    redirect_to kitchen_path, alert: "Failed to link Hackatime: #{e.record.errors.full_messages.first}"
  end
end

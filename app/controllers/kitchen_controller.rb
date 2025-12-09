class KitchenController < ApplicationController
  def index
    authorize :kitchen, :index?

    unless current_user.verification_verified? && current_user.ysws_eligible == true
      @verification_rejection_reason = refresh_verification_status_from_hca!
      current_user.reload
    end

    @has_hackatime_linked = current_user.has_hackatime?
    @has_identity_linked = current_user.identity_verified?

    @tutorial_steps = User::TutorialStep.all
    @completed_steps = current_user.tutorial_steps
    @tutorial_is_complete = @tutorial_steps - @completed_steps
  end

  private

  # temp
  def refresh_verification_status_from_hca!
    identity = current_user.identities.find_by(provider: "hack_club")
    return unless identity&.access_token.present?

    identity_payload = HCAService.identity(identity.access_token)
    return if identity_payload.blank?

    latest_status = identity_payload["verification_status"].to_s
    return unless User.verification_statuses.key?(latest_status)

    ysws_eligible = identity_payload["ysws_eligible"] == true

    current_user.complete_tutorial_step!(:identity_verified) if latest_status == "verified"

    current_user.verification_status = latest_status
    current_user.ysws_eligible = ysws_eligible

    current_user.save!

    {
      "reason" => identity_payload["rejection_reason"],
      "details" => identity_payload["rejection_reason_details"]
    }.compact_blank.presence
  rescue StandardError => e
    Rails.logger.warn("Kitchen HCA refresh failed: #{e.class}: #{e.message}")
    nil
  end
end

class KitchenController < ApplicationController
  def index
    authorize :kitchen, :index?

    # temp: Refresh verification_status from HCA and DB
    # TODO: PR to idv
    refresh_verification_status_from_hca!
    current_user.reload

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
    return unless User::VALID_VERIFICATION_STATUSES.include?(latest_status)

    ysws_eligible = identity_payload["ysws_eligible"] == true

    current_user.complete_tutorial_step!(:identity_verified) if latest_status == "verified"

    updates = {}
    updates[:verification_status] = latest_status if current_user.verification_status.to_s != latest_status
    updates[:ysws_eligible] = ysws_eligible if current_user.ysws_eligible != ysws_eligible

    current_user.update!(updates) if updates.present?
  rescue StandardError => e
    Rails.logger.warn("Kitchen HCA refresh failed: #{e.class}: #{e.message}")
  end
end

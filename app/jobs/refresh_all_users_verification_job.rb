# frozen_string_literal: true

class RefreshAllUsersVerificationJob < ApplicationJob
  queue_as :default

  def perform
    User.joins(:identities)
        .where(user_identities: { provider: "hack_club" })
        .where.not(user_identities: { access_token: [ nil, "" ] })
        .includes(:identities)
        .find_each do |user|
      refresh_verification_status(user)
    end
  end

  private

  def refresh_verification_status(user)
    identity = user.identities.find_by(provider: "hack_club")
    return unless identity&.access_token.present?

    payload = HCAService.identity(identity.access_token)
    return if payload.blank?

    status = payload["verification_status"].to_s
    return unless User::VALID_VERIFICATION_STATUSES.include?(status)

    ysws_eligible = payload["ysws_eligible"] == true

    user.verification_status = status
    user.ysws_eligible = ysws_eligible
    user.save!
  rescue StandardError => e
    Rails.logger.error "Failed to refresh verification status for user #{user.id}: #{e.message}"
    Sentry.capture_exception(e, extra: { user_id: user.id })
  end
end

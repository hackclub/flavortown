# frozen_string_literal: true

class Shop::RefreshVerificationStatusJob < ApplicationJob
  queue_as :default

  def perform
    user_ids = ShopOrder.where(aasm_state: "awaiting_verification")
                        .distinct.pluck(:user_id)

    User.where(id: user_ids)
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
    return unless User.verification_statuses.key?(status)

    ysws_eligible = payload["ysws_eligible"] == true

    user.verification_status = status
    user.ysws_eligible = ysws_eligible
    user.save!

    if user.eligible_for_shop?
      Shop::ProcessVerifiedOrdersJob.perform_later(user.id)
    elsif user.should_reject_orders?
      user.reject_awaiting_verification_orders!
    end

  rescue StandardError => e
    Rails.logger.error "Failed to refresh verification status for user #{user.id}: #{e.message}"
    Sentry.capture_exception(e, extra: { user_id: user.id })
  end
end

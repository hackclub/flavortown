# frozen_string_literal: true

class Shop::RefreshVerificationStatusJob < ApplicationJob
  queue_as :default

  def perform
    user_ids = ShopOrder.where(aasm_state: "awaiting_verification")
                        .distinct.pluck(:user_id)

    User.where(id: user_ids).find_each do |user|
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

    updates = {}
    updates[:verification_status] = status if user.verification_status != status
    updates[:ysws_eligible] = ysws_eligible if user.ysws_eligible != ysws_eligible

    user.update!(updates) if updates.present?
  rescue StandardError => e
    Rails.logger.warn("Failed to refresh verification status for user #{user.id}: #{e.message}")
  end
end

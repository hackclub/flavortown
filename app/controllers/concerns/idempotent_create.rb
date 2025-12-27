# frozen_string_literal: true

module IdempotentCreate
  extend ActiveSupport::Concern

  IDEMPOTENCY_TOKEN_EXPIRY = 5.minutes

  private

  def idempotency_token_used?(token)
    return false if token.blank?

    cache_key = "idempotency:#{current_user&.id}:#{token}"
    Rails.cache.exist?(cache_key)
  end

  def mark_idempotency_token_used!(token)
    return if token.blank?

    cache_key = "idempotency:#{current_user&.id}:#{token}"
    Rails.cache.write(cache_key, true, expires_in: IDEMPOTENCY_TOKEN_EXPIRY)
  end

  def check_idempotency_token!
    token = params[:idempotency_token]
    return unless token.present?

    if idempotency_token_used?(token)
      flash[:notice] = "This action has already been completed"
      yield if block_given?
      true
    else
      false
    end
  end
end

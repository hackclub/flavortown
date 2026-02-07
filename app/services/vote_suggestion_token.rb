require "digest"

class VoteSuggestionToken
  PURPOSE = "vote_suggestion_v1"
  TTL = 30.minutes

  def self.issue(user:, ship_event:, user_agent: nil)
    payload = {
      "user_id" => user.id,
      "ship_event_id" => ship_event.id,
      "ua" => ua_fingerprint(user_agent),
      "expires_at" => Time.current.to_i + TTL.to_i
    }

    verifier.generate(payload)
  end

  def self.verify(token, user:, user_agent: nil)
    return nil if token.blank?

    payload = verifier.verify(token)

    payload = payload.stringify_keys if payload.respond_to?(:stringify_keys)
    return nil unless payload.is_a?(Hash)

    expires_at = payload["expires_at"].to_i
    return nil if expires_at.zero? || Time.current.to_i > expires_at

    return nil unless payload["user_id"].to_i == user.id

    return nil unless payload["ua"].to_s == ua_fingerprint(user_agent)

    payload["ship_event_id"].to_i
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageVerifier::InvalidMessage
    nil
  rescue => e
    Rails.logger.warn "VoteSuggestionToken verification failed: #{e.message}"
    nil
  end

  def self.verifier
    Rails.application.message_verifier(PURPOSE)
  end
  private_class_method :verifier

  def self.ua_fingerprint(user_agent)
    Digest::SHA256.hexdigest(user_agent.to_s)[0, 16]
  end
  private_class_method :ua_fingerprint
end

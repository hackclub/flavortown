# frozen_string_literal: true

class FunnelTrackerService
  class << self
    # Track a funnel event
    #
    # @param event_name [String] The name of the event (e.g., "start_step_completed", "first_login")
    # @param user [User, nil] The user associated with this event (optional for pre-signup events)
    # @param email [String, nil] The email for pre-signup tracking (required if user is nil)
    # @param properties [Hash] Additional properties to store with the event
    # @return [FunnelEvent, nil] The created event or nil if creation fails
    def track(event_name:, user: nil, email: nil, properties: {})
      normalized_email = normalize_email(email) if email.present?

      FunnelEvent.create(
        event_name: event_name,
        user_id: user&.id,
        email: normalized_email || user&.email,
        properties: properties
      )
    rescue StandardError => e
      Rails.logger.error("FunnelTrackerService.track failed: #{e.message}")
      nil
    end

    # Link pre-signup events (tracked by email) to a user after authentication
    #
    # @param user [User] The user to link events to
    # @param email [String] The email to match events by
    # @return [Integer] The number of events updated
    def link_events_to_user(user, email)
      return 0 unless user && email.present?

      normalized_email = normalize_email(email)
      FunnelEvent.pre_signup.for_email(normalized_email).update_all(user_id: user.id)
    rescue StandardError => e
      Rails.logger.error("FunnelTrackerService.link_events_to_user failed: #{e.message}")
      0
    end

    # Normalize email for consistent matching
    #
    # @param email [String] The email to normalize
    # @return [String] The normalized email (lowercase, stripped)
    def normalize_email(email)
      email.to_s.strip.downcase
    end
  end
end

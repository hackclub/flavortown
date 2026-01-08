# frozen_string_literal: true

class StartFlowReminderJob < ApplicationJob
    queue_as :default

    START_FLOW_EVENTS = %w[
      start_flow_started
      start_flow_name
      start_flow_project
      start_flow_devlog
    ].freeze

    SIGNIN_EVENT   = "start_flow_signin"
    REMINDER_EVENT = "start_flow_reminder_sent"

    def self.send_to_email(email, skip_tracking: false)
      new.send_reminder(email, manual: true, skip_tracking: skip_tracking)
    end

    def perform
      emails = eligible_emails
      Rails.logger.info("StartFlowReminderJob: Found #{emails.size} eligible emails")

      emails.each { |email| send_reminder(email) }

      Rails.logger.info("StartFlowReminderJob: Completed processing reminders")
    end

    private

    # around ~4.7k users
    def eligible_emails
      started  = normalized_emails(FunnelEvent.where(event_name: START_FLOW_EVENTS))
      signed_in = normalized_emails(FunnelEvent.by_event(SIGNIN_EVENT))
      reminded  = normalized_emails(FunnelEvent.by_event(REMINDER_EVENT))

      (started - signed_in - reminded).compact
    end

    def normalized_emails(scope)
      scope.where.not(email: nil).distinct.pluck(:email).map { FunnelEvent.normalize_email_for_query(_1) }.uniq
    end

    def send_reminder(email, manual: false, skip_tracking: false)
      normalized = FunnelEvent.normalize_email_for_query(email)

      if Rails.env.production?
        StartFlowReminderMailer.signin_reminder(normalized).deliver_later
      else
        Rails.logger.info("StartFlowReminderJob: Would send reminder to #{normalized} if in production")
      end

      track_sent(normalized, manual: manual) unless skip_tracking
      Rails.logger.info("StartFlowReminderJob: Sent reminder to #{normalized}")
      true
    rescue => e
      Rails.logger.error("StartFlowReminderJob: Failed to send reminder to #{normalized}: #{e.message}")
      Sentry.capture_exception(e, extra: { email: normalized, manual: manual }) if defined?(Sentry)
      raise if manual
    end

    def track_sent(email, manual:)
      FunnelTrackerService.track(
        event_name: REMINDER_EVENT,
        email: email,
        properties: {
          sent_at: Time.current.iso8601,
          manual: manual,
          environment: Rails.env
        }.compact
      )
    end
end

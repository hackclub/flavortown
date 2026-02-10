class ShipCertWebhookJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: Float::INFINITY
  discard_on ProjectNotShippableError
  discard_on DuplicateShipError

  def perform(ship_event_id:, type: nil, force: false)
    return if !force && already_processed?(ship_event_id)

    ship_event = Post::ShipEvent.find_by(id: ship_event_id)
    return unless ship_event

    project = ship_event.project
    return unless project

    # Verify project is still shippable
    unless project.shippable?
      errors = project.ship_blocking_errors.join(", ")
      Rails.logger.warn "Ship cert job discarded: Project #{project.id} is not shippable. Errors: #{errors}"
      raise ProjectNotShippableError, "Project #{project.id} failed shipping requirements: #{errors}"
    end

    ShipCertService.send_webhook(project, type: type, ship_event: ship_event)
    mark_as_processed!(ship_event_id)
  end

  private

  def cache_key(ship_event_id)
    "ship_cert_webhook_job:#{ship_event_id}"
  end

  def already_processed?(ship_event_id)
    Rails.cache.exist?(cache_key(ship_event_id))
  end

  def mark_as_processed!(ship_event_id)
    Rails.cache.write(cache_key(ship_event_id), true, expires_in: 24.hours)
  end
end

class ProjectNotShippableError < StandardError; end

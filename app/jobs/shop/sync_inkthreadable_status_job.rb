class Shop::SyncInkthreadableStatusJob < ApplicationJob
  queue_as :default

  SHIPPED_STATUSES = [ "quality control" ].freeze
  ALERT_SLACK_ID = "U054VC2KM9P" # @transcental

  def perform
    pending_inkthreadable_orders.find_each do |order|
      sync_order_status(order)
    rescue => e
      Rails.logger.error "[InkthreadableSync] Failed to sync order #{order.id}: #{e.message}"
    end
  end

  private

  def pending_inkthreadable_orders
    ShopOrder
      .joins(:shop_item)
      .where(shop_items: { type: "ShopItem::InkthreadableItem" })
      .where.not(aasm_state: %w[fulfilled rejected refunded])
      .where("external_ref LIKE 'INK-%'")
  end

  def sync_order_status(order)
    inkthreadable_id = order.external_ref.delete_prefix("INK-")
    response = InkthreadableService.get_order(inkthreadable_id)

    ink_order = response["order"]
    return unless ink_order

    status = ink_order["status"]&.downcase
    shipping = ink_order["shipping"] || {}
    tracking_number = shipping["trackingNumber"]
  # either the docs are wrong or its the brits faults  - neon
    shipped_at = shipping["shiped_at"] || shipping["shipped_at"]

    if shipped_at.present? || tracking_number.present?
      mark_as_fulfilled(order, tracking_number)
    elsif status == "refunded" || ink_order["deleted"] == "true"
      handle_cancelled(order)
    else
      handle_unexpected_status(order, status)
    end
  end

  def handle_unexpected_status(order, status)
    message = "[InkthreadableSync] Order #{order.id} has unexpected status: #{status}"
    Rails.logger.warn message

    Sentry.capture_message(message, level: :warning, extra: { order_id: order.id, status: status })

    order.send_fulfillment_alert!("Inkthreadable order has unexpected status: *#{status}*")
  end

  def mark_as_fulfilled(order, tracking_number)
    external_ref = tracking_number.present? ? "INK-#{tracking_number}" : order.external_ref
    order.mark_fulfilled!(external_ref)
    Rails.logger.info "[InkthreadableSync] Order #{order.id} marked as fulfilled with tracking: #{tracking_number}"
  end

  def handle_cancelled(order)
    Rails.logger.warn "[InkthreadableSync] Order #{order.id} was refunded/cancelled in Inkthreadable"
    order.mark_rejected!("Cancelled by Inkthreadable")
  end
end

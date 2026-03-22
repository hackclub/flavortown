# frozen_string_literal: true

class Shop::SendInkthreadableOrderJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = ShopOrder.find(order_id)
    shop_item = order.shop_item

    unless shop_item.is_a?(ShopItem::InkthreadableItem)
      Rails.logger.warn "[Inkthreadable] Order #{order_id} is not an Inkthreadable item, skipping"
      return
    end

    address = order.frozen_address
    if address.blank?
      Rails.logger.error "[Inkthreadable] Order #{order_id} missing address"
      return
    end

    payload = build_order_payload(order, shop_item, address)

    response = InkthreadableService.create_order(payload)

    inkthreadable_order_id = response.dig("order", "id")
    if inkthreadable_order_id.present?
      order.update!(external_ref: "INK-#{inkthreadable_order_id}")
      Rails.logger.info "[Inkthreadable] Order #{order_id} submitted successfully as #{inkthreadable_order_id}"
    else
      Rails.logger.error "[Inkthreadable] Order #{order_id} response missing order.id: #{response.inspect}"
      raise "Inkthreadable response missing order.id"
    end
  rescue Faraday::Error => e
    Rails.logger.error "[Inkthreadable] Failed to send order #{order_id}: #{e.message}"
    Rails.logger.error e.response&.dig(:body) if e.respond_to?(:response)
    raise
  end

  private

  def build_order_payload(order, shop_item, address)
    payload = {
      external_id: "FT-#{order.id}",
      shipping_address: {
        firstName: address["first_name"] || address["firstName"] || order.user.display_name.split.first,
        lastName: address["last_name"] || address["lastName"] || order.user.display_name.split.last,
        company: address["company"],
        address1: address["address1"] || address["line1"],
        address2: address["address2"] || address["line2"],
        city: address["city"],
        county: address["state"] || address["county"],
        postcode: address["postcode"] || address["zip"] || address["postal_code"],
        country: address["country"],
        phone1: address["phone"] || address["phone1"]
      }.compact,
      shipping: {
        shippingMethod: shop_item.shipping_method
      },
      items: build_order_items(order, shop_item)
    }

    payload[:brandName] = shop_item.brand_name if shop_item.brand_name.present?
    payload[:comment] = "Flavortown order ##{order.id}" if Rails.env.production?

    payload
  end

  def build_order_items(order, shop_item)
    [
      {
        pn: shop_item.product_number,
        quantity: order.quantity,
        designs: shop_item.design_urls
      }.compact
    ]
  end
end

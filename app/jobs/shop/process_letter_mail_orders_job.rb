# frozen_string_literal: true

class Shop::ProcessLetterMailOrdersJob < ApplicationJob
  queue_as :default

  def perform
    orders = ShopOrder.joins(:shop_item)
                      .where(shop_items: { type: "ShopItem::LetterMail" })
                      .where(aasm_state: "awaiting_periodical_fulfillment")

    orders.each do |order|
      process_order(order)
    rescue => e
      Rails.logger.error("Failed to process letter mail order ##{order.id}: #{e.message}")
    end
  end

  private

  def process_order(order)
    letter_id = TheseusService.create_letter(order, queue: "flavortown-envelope")
    order.mark_fulfilled!(letter_id, nil, "System - Letter Mail")
  end
end

class QueueController < ApplicationController

  def index
    @pending_orders = ShopOrder.pending.order(created_at: :asc)
    @on_hold_orders = ShopOrder.on_hold.order(created_at: :asc)
    @avg_response_hours = avg_response_orders

    backlog = ShopOrder.where(aasm_state: %w[pending on_hold])
    @oldest_waiting = backlog.minimum(:created_at)
    @newest_waiting = backlog.maximum(:created_at)
    avg_epoch = backlog.pick(Arel.sql("AVG(EXTRACT(EPOCH FROM created_at))"))
    @avg_wait = avg_epoch ? ((Time.current.to_f - avg_epoch) / 3600).round(1) : nil

    @by_item_type = backlog.joins(:shop_item).group("shop_items.type").count
  end

  private

  def avg_response_orders
    orders = ShopOrder.where(aasm_state: %w[awaiting_periodical_fulfillment rejected fulfilled])
                      .where("created_at > ?", 30.days.ago).limit(100)
    return nil if orders.empty?

    total = orders.sum do |o|
      v = o.versions.find { |ver| ver.object_changes&.dig("aasm_state")&.last.in?(%w[awaiting_periodical_fulfillment rejected]) }
      v ? (v.created_at - o.created_at) / 1.hour : 0
    end
    (total / orders.count).round(1)
  end
end

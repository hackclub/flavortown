class QueueController < ApplicationController
  def index
    backlog = ShopOrder.where(aasm_state: %w[pending on_hold])
                       .includes(:shop_item)
                       .order(created_at: :asc)
                       .load

    @pending_orders = backlog.select { |o| o.aasm_state == "pending" }
    @on_hold_orders = backlog.select { |o| o.aasm_state == "on_hold" }
    @pending_count = @pending_orders.size
    @on_hold_count = @on_hold_orders.size
    @avg_response_hours = avg_response_hours_cached

    if backlog.any?
      timestamps = backlog.map(&:created_at)
      @oldest_waiting = timestamps.min
      @newest_waiting = timestamps.max
      @avg_wait = ((Time.current.to_f - timestamps.sum(&:to_f) / timestamps.size) / 3600).round(1)
      @by_item_type = backlog.group_by { |o| o.shop_item.type }.transform_values(&:count)
    else
      @oldest_waiting = @newest_waiting = @avg_wait = nil
      @by_item_type = {}
    end
  end

  private

  def avg_response_hours_cached
    Rails.cache.fetch("queue/avg_response_hours", expires_in: 10.minutes) do
      compute_avg_response_hours
    end
  end

  def compute_avg_response_hours
    orders = ShopOrder.where(aasm_state: %w[awaiting_periodical_fulfillment rejected fulfilled])
                      .where("created_at > ?", 30.days.ago)
                      .includes(:versions)
                      .limit(100)
    return nil if orders.empty?

    target_states = %w[awaiting_periodical_fulfillment rejected]
    total = orders.sum do |o|
      v = o.versions.find { |ver| ver.object_changes&.dig("aasm_state")&.last.in?(target_states) }
      v ? (v.created_at - o.created_at) / 1.hour : 0
    end
    (total / orders.size).round(1)
  end
end

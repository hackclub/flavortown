class QueueController < ApplicationController
  CACHE_TTL = 5.minutes

  def index
    cached_data = Rails.cache.fetch("queue/index_data", expires_in: CACHE_TTL) do
      compute_index_data
    end

    @pending_count = cached_data[:pending_count]
    @oldest_waiting = cached_data[:oldest_waiting]
    @newest_waiting = cached_data[:newest_waiting]
    @avg_wait = cached_data[:avg_wait]
    @by_item_type = cached_data[:by_item_type]
    @avg_response_hours = cached_data[:avg_response_hours]
    @pending_orders = cached_data[:pending_orders] || []
  end

  private

  def compute_index_data
    backlog = ShopOrder.where(aasm_state: "pending")
                       .includes(:shop_item)
                       .order(created_at: :asc)
                       .load

    pending_count = backlog.size
    avg_response_hours = compute_avg_response_hours

    if backlog.any?
      timestamps = backlog.map(&:created_at)
      oldest_waiting = timestamps.min
      newest_waiting = timestamps.max
      avg_wait = ((Time.current.to_f - timestamps.sum(&:to_f) / timestamps.size) / 3600).round(1)
      by_item_type = backlog.group_by { |o| o.shop_item&.type }.transform_values(&:count)
    else
      oldest_waiting = newest_waiting = avg_wait = nil
      by_item_type = {}
    end

    {
      pending_count: pending_count,
      oldest_waiting: oldest_waiting,
      newest_waiting: newest_waiting,
      avg_wait: avg_wait,
      by_item_type: by_item_type,
      avg_response_hours: avg_response_hours,
      pending_orders: backlog
    }
  end

  def compute_avg_response_hours
    orders = ShopOrder.where(aasm_state: %w[awaiting_periodical_fulfillment rejected fulfilled])
                      .where("created_at > ?", 30.days.ago)
                      .includes(:versions)
                      .limit(100)
    return nil if orders.empty?

    target_states = %w[awaiting_periodical_fulfillment rejected]
    total = orders.sum do |o|
      v = o.versions.find do |ver|
        changes = ver.object_changes
        changes = JSON.parse(changes) if changes.is_a?(String)
        changes&.dig("aasm_state")&.last.in?(target_states)
      end
      v ? (v.created_at - o.created_at) / 1.hour : 0
    end
    (total / orders.size).round(1)
  end
end

class QueueController < ApplicationController
  CACHE_TTL = 5.minutes

  def index
    cached_data = Rails.cache.fetch("queue/index_data", expires_in: CACHE_TTL) do
      compute_index_data
    end

    @pending_only_count = cached_data[:pending_only_count] || 0
    @pending_count = cached_data[:pending_count]
    @oldest_waiting = cached_data[:oldest_waiting]
    @newest_waiting = cached_data[:newest_waiting]
    @avg_wait = cached_data[:avg_wait]
    @by_item_type = cached_data[:by_item_type]
    @avg_response_hours = cached_data[:avg_response_hours]
    @pending_orders = cached_data[:pending_orders] || []
    @periodic_orders = cached_data[:periodic_orders] || []
    @periodic_transitioned_at = cached_data[:periodic_transitioned_at] || {}
    @fulfilment_count = cached_data[:fulfilment_count] || 0
    @region_stats = cached_data[:region_stats] || []
  end

  private

  def compute_index_data
    backlog = ShopOrder.where(aasm_state: %w[pending on_hold])
                       .includes(:shop_item)
                       .order(created_at: :asc)
                       .load

    periodic = ShopOrder.where(aasm_state: "awaiting_periodical_fulfillment")
                        .includes(:shop_item, :versions)
                        .order(created_at: :asc)
                        .load

    periodic_transitioned_at = periodic.each_with_object({}) do |order, hash|
      v = order.versions.find do |ver|
        changes = ver.object_changes
        next if changes.is_a?(String) && changes.start_with?("---")
        changes = JSON.parse(changes) if changes.is_a?(String)
        changes&.dig("aasm_state")&.last == "awaiting_periodical_fulfillment"
      end
      hash[order.id] = v&.created_at
    end

    pending_only_count = backlog.count { |o| o.aasm_state == "pending" }
    pending_count = backlog.size
    fulfilment_count = ShopOrder.where(aasm_state: %w[awaiting_periodical_fulfillment awaiting_verification_call]).count
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
      pending_only_count: pending_only_count,
      pending_count: pending_count,
      fulfilment_count: fulfilment_count,
      region_stats: compute_region_stats,
      oldest_waiting: oldest_waiting,
      newest_waiting: newest_waiting,
      avg_wait: avg_wait,
      by_item_type: by_item_type,
      avg_response_hours: avg_response_hours,
      pending_orders: backlog,
      periodic_orders: periodic,
      periodic_transitioned_at: periodic_transitioned_at
    }
  end

  def compute_region_stats
    backlog_by_region = ShopOrder.where(aasm_state: %w[pending on_hold])
                                 .group(:region)
                                 .count

    avg_time_by_region = ShopOrder.where(aasm_state: "fulfilled")
                                  .where("updated_at > ?", 30.days.ago)
                                  .select(:region, :created_at, :updated_at)
                                  .group_by(&:region)
                                  .transform_values do |orders|
                                    (orders.sum { |o| (o.updated_at - o.created_at) / 1.hour } / orders.size).round(1)
                                  end

    Shop::Regionalizable::REGIONS.map do |code, config|
      {
        code: code,
        name: config[:name],
        backlog: backlog_by_region[code] || 0,
        avg_fulfillment_hours: avg_time_by_region[code]
      }
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
      v = o.versions.find do |ver|
        changes = ver.object_changes
        next if changes.is_a?(String) && changes.start_with?("---")
        changes = JSON.parse(changes) if changes.is_a?(String)
        changes&.dig("aasm_state")&.last.in?(target_states)
      end
      v ? (v.created_at - o.created_at) / 1.hour : 0
    end
    (total / orders.size).round(1)
  end
end

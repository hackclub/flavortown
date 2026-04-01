# frozen_string_literal: true

module Admin
  module SuperMegaDashboard
    module FulfillmentStats
      extend ActiveSupport::Concern

      private

      def load_fulfillment_stats
        cached_data = Rails.cache.fetch("super_mega_fulfillment", expires_in: 10.minutes) do
          base_scope = ShopOrder.joins(:shop_item)
                                .where(aasm_state: %w[pending awaiting_periodical_fulfillment])
                                .where.not(shop_items: { type: "ShopItem::FreeStickers" })

          type_counts = base_scope.group("shop_items.type", :aasm_state).count

          known_types = %w[
            ShopItem::HQMailItem ShopItem::LetterMail
            ShopItem::ThirdPartyPhysical ShopItem::Accessory ShopItem::ThirdPartyDigital
            ShopItem::WarehouseItem ShopItem::PileOfStickersItem
            ShopItem::FreeStickers
          ]
          other_types = type_counts.keys.map(&:first).uniq - known_types

          fulfilled_counts = ShopOrder.joins(:shop_item)
                                      .where(aasm_state: "fulfilled")
                                      .where.not(shop_items: { type: "ShopItem::FreeStickers" })
                                      .group("shop_items.type").count

          warehouse_has_stale = ShopOrder.joins(:shop_item)
                                         .where(aasm_state: "awaiting_periodical_fulfillment")
                                         .where(shop_items: { type: %w[ShopItem::WarehouseItem ShopItem::PileOfStickersItem] })
                                         .where("shop_orders.awaiting_periodical_fulfillment_at <= ?", 3.days.ago)
                                         .exists?

          {
            all: calculate_type_totals(type_counts, nil, fulfilled_counts),
            hq_mail: calculate_type_totals(type_counts, %w[ShopItem::HQMailItem ShopItem::LetterMail], fulfilled_counts),
            third_party: calculate_type_totals(type_counts, %w[ShopItem::ThirdPartyPhysical ShopItem::Accessory ShopItem::ThirdPartyDigital], fulfilled_counts),
            warehouse: calculate_type_totals(type_counts, %w[ShopItem::WarehouseItem ShopItem::PileOfStickersItem], fulfilled_counts),
            other: calculate_type_totals(type_counts, other_types, fulfilled_counts),
            warehouse_has_stale: warehouse_has_stale
          }
        end
        @fulfillment = cached_data || { all: {}, hq_mail: {}, third_party: {}, warehouse: {}, other: {}, warehouse_has_stale: false }
        @fulfillment_trend_data = build_fulfillment_trend_data
        @order_states_trend_data = build_order_states_trend_data
        @recent_new_items = ShopItem.recently_added.enabled.includes(image_attachment: :blob).limit(12)
      end

      def build_fulfillment_trend_data
        Rails.cache.fetch("super_mega_fulfillment_trend", expires_in: 1.hour) do
          window_start = 29.days.ago.beginning_of_day
          window_end = Time.current.end_of_day

          fulfilled_by_date = ShopOrder.where(fulfilled_at: window_start..window_end)
                                       .group(Arel.sql("DATE(fulfilled_at)")).count
          created_by_date = ShopOrder.real.where(created_at: window_start..window_end)
                                         .group(Arel.sql("DATE(created_at)")).count

          (0..29).reverse_each.each_with_object({}) do |days_ago, trend_data|
            date = days_ago.days.ago.to_date
            trend_data[date.to_s] = {
              fulfilled: fulfilled_by_date[date] || 0,
              created: created_by_date[date] || 0
            }
          end
        end
      end

      def build_order_states_trend_data
        Rails.cache.fetch("super_mega_order_states_trend", expires_in: 1.hour) do
          window_start = 29.days.ago.beginning_of_day
          window_end = Time.current.end_of_day

          pending_by_date = ShopOrder.real.where(created_at: window_start..window_end)
                                         .group(Arel.sql("DATE(created_at)")).count
          awaiting_by_date = ShopOrder.where(awaiting_periodical_fulfillment_at: window_start..window_end)
                                      .group(Arel.sql("DATE(awaiting_periodical_fulfillment_at)")).count
          fulfilled_by_date = ShopOrder.where(fulfilled_at: window_start..window_end)
                                       .group(Arel.sql("DATE(fulfilled_at)")).count
          on_hold_by_date = ShopOrder.where(on_hold_at: window_start..window_end)
                                     .group(Arel.sql("DATE(on_hold_at)")).count
          rejected_by_date = ShopOrder.where(rejected_at: window_start..window_end)
                                      .group(Arel.sql("DATE(rejected_at)")).count

          (0..29).reverse_each.each_with_object({}) do |days_ago, trend_data|
            date = days_ago.days.ago.to_date
            fulfilled = fulfilled_by_date[date] || 0
            rejected = rejected_by_date[date] || 0
            trend_data[date.to_s] = {
              pending: pending_by_date[date] || 0,
              awaiting_periodical_fulfillment: awaiting_by_date[date] || 0,
              on_hold: on_hold_by_date[date] || 0,
              closed: fulfilled + rejected
            }
          end
        end
      end

      def calculate_type_totals(type_counts, filter_types = nil, fulfilled_counts = {})
        awaiting = 0

        type_counts.each do |(type, state), count|
          next if filter_types && !filter_types.include?(type)

          awaiting += count if state == "awaiting_periodical_fulfillment"
        end

        fulfilled = fulfilled_counts.sum do |type, count|
          (filter_types.nil? || filter_types.include?(type)) ? count : 0
        end

        { awaiting: awaiting, fulfilled: fulfilled }
      end
    end
  end
end

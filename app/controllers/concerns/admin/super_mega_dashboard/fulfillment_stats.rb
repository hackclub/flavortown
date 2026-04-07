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
        @common_shop_suggestions = get_shop_suggestions
      rescue StandardError => e
        Rails.logger.warn("[SuperMegaDashboard] Fulfillment stats failed (#{e.class}): #{e.message}")

        blank_stats = { awaiting: "—", fulfilled: "—" }
        @fulfillment = {
          all: blank_stats.dup,
          hq_mail: blank_stats.dup,
          third_party: blank_stats.dup,
          warehouse: blank_stats.dup,
          other: blank_stats.dup,
          warehouse_has_stale: false
        }
        @fulfillment_trend_data = nil
        @order_states_trend_data = nil
        @recent_new_items = []
        @common_shop_suggestions = []
      end

      def build_fulfillment_trend_data
        Rails.cache.fetch("super_mega_fulfillment_trend", expires_in: 1.hour) do
          window_start = 29.days.ago.beginning_of_day
          window_end = Time.current.end_of_day

          fulfilled_by_date = ShopOrder.where(fulfilled_at: window_start..window_end)
                                       .group(Arel.sql("DATE(fulfilled_at)")).count
          created_by_date = ShopOrder.real.where(created_at: window_start..window_end)
                                         .group(Arel.sql("DATE(shop_orders.created_at)")).count

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
                                         .group(Arel.sql("DATE(shop_orders.created_at)")).count
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

      def get_shop_suggestions
        cache_key = "shop_suggestion_llm_results"
        cached = Rails.cache.read(cache_key)
        last_called = cached&.dig(:last_called)

        return cached[:result] if last_called.present? && last_called >= 24.hours.ago

        items = ShopSuggestion.order(created_at: :desc).limit(500).pluck(:item)
        llm_result = get_common_suggestions(items)

        if llm_result.present?
          Rails.cache.write(cache_key, { result: llm_result, last_called: Time.current })
          llm_result
        else
          cached&.dig(:result) || []
        end
      end

      def get_common_suggestions(items)
        return [] if items.blank?

        prompt = <<~PROMPT
          Analyze the following suggestions for a hacker shop and identify 8-10 of the most commonly requested items or themes.

          INPUT DATA:
          #{JSON.generate(items)}

          OUTPUT INSTRUCTIONS:
          Return only valid JSON with no markdown formatting or code blocks, following this exact schema:
          [suggestion1, suggestion2, ...]
        PROMPT

        llm_response = Faraday.post("https://openrouter.ai/api/v1/chat/completions") do |req|
          req.headers["Authorization"] = "Bearer #{ENV['OPENROUTER_API_KEY']}"
          req.headers["Content-Type"] = "application/json"
          req.body = {
            model: "x-ai/grok-4.1-fast",
            messages: [
              { role: "user", content: prompt }
            ]
          }.to_json
        end

        unless llm_response.success?
          return []
        end

        llm_body = JSON.parse(llm_response.body)
        content = llm_body.dig("choices", 0, "message", "content")
        cleaned_content = content.gsub(/^```json\s*|```\s*$/, "")
        data = JSON.parse(cleaned_content)

        data
      rescue JSON::ParserError => e
        []
      end
    end
  end
end

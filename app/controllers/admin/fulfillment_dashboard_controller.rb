# frozen_string_literal: true

module Admin
  class FulfillmentDashboardController < ApplicationController
    before_action :ensure_authorized_user

    def index
      @fulfillment_type = params[:fulfillment_type] || "all"
      @show_warehouse = params[:show_warehouse] == "true"
      @pagy, @orders = pagy(:offset, filtered_orders(@fulfillment_type))
      generate_statistics
    end

    def send_letter_mail
      # TODO replace with the real job
      # Shop::ProcessLetterMailOrdersJob.perform_later
      redirect_to "https://mail.hackclub.com/back_office/letter/queues/flavortown-fulfillment#letters", allow_other_host: true
    end

    private

    def fulfillment_type_filters
      {
        "hq_mail" => [ "ShopItem::HQMailItem", "ShopItem::LetterMail" ],
        "third_party" => "ShopItem::ThirdPartyPhysical",
        "warehouse" => [ "ShopItem::WarehouseItem", "ShopItem::PileOfStickersItem" ],
        "free_stickers" => "ShopItem::FreeStickers",
        "other" => [
          "ShopItem::HCBGrant",
          "ShopItem::SiteActionItem",
          "ShopItem::BadgeItem",
          "ShopItem::AdventSticker",
          "ShopItem::HCBPreauthGrant",
          "ShopItem::SpecialFulfillmentItem"
        ]
      }
    end

    def base_fulfillment_scope(include_associations: false, include_free_stickers: false)
      scope = ShopOrder.where(aasm_state: [ "pending", "awaiting_periodical_fulfillment" ])
                       .joins(:shop_item)

      scope = scope.where.not(shop_items: { type: "ShopItem::FreeStickers" }) unless include_free_stickers

      if include_associations
        scope = scope.includes(:user, :shop_item, :assigned_to_user)
                     .order(:awaiting_periodical_fulfillment_at, :created_at)
      end

      scope
    end

    def filtered_orders(fulfillment_type)
      include_free_stickers = fulfillment_type == "free_stickers"
      base_scope = base_fulfillment_scope(include_associations: true, include_free_stickers: include_free_stickers)

      if fulfillment_type == "all" && !@show_warehouse
        base_scope = base_scope.where.not(shop_items: { type: [ "ShopItem::WarehouseItem", "ShopItem::PileOfStickersItem" ] })
      end

      if fulfillment_type == "all" || !fulfillment_type_filters.key?(fulfillment_type)
        base_scope
      else
        shop_item_types = fulfillment_type_filters[fulfillment_type]
        base_scope.where(shop_items: { type: shop_item_types })
      end
    end

    def generate_statistics
      base_orders = base_fulfillment_scope
      base_orders_with_free = base_fulfillment_scope(include_free_stickers: true)

      @stats = {}

      fulfillment_type_filters.each do |type, shop_item_types|
        scope = type == "free_stickers" ? base_orders_with_free : base_orders
        @stats[type.to_sym] = generate_type_stats(scope.where(shop_items: { type: shop_item_types }))
      end

      @stats[:all] = generate_type_stats(base_orders)

      # Generate regional stats for third_party (Amber & Co)
      @regional_stats = generate_regional_stats_for_third_party
    end

    def generate_regional_stats_for_third_party
      third_party_orders = base_fulfillment_scope(include_associations: true)
                            .where(shop_items: { type: "ShopItem::ThirdPartyPhysical" })

      regional_data = {}
      Shop::Regionalizable::REGION_CODES.each do |region_code|
        regional_data[region_code] = { pc: 0, ac: 0, aho: 0, ahf: 0, order_times: [], fulfill_times: [] }
      end

      third_party_orders.each do |order|
        next unless order.frozen_address.present?

        region = Shop::Regionalizable.country_to_region(order.frozen_address["country"])
        regional_data[region] ||= { pc: 0, ac: 0, aho: 0, ahf: 0, order_times: [], fulfill_times: [] }

        if order.aasm_state == "pending"
          regional_data[region][:pc] += 1
          regional_data[region][:order_times] << (Time.current - order.created_at).to_i
        elsif order.aasm_state == "awaiting_periodical_fulfillment"
          regional_data[region][:ac] += 1
          if order.awaiting_periodical_fulfillment_at
            regional_data[region][:fulfill_times] << (Time.current - order.awaiting_periodical_fulfillment_at).to_i
          end
        end
      end

      # Calculate averages
      regional_data.each do |region, data|
        data[:aho] = data[:order_times].any? ? (data[:order_times].sum / data[:order_times].size) : 0
        data[:ahf] = data[:fulfill_times].any? ? (data[:fulfill_times].sum / data[:fulfill_times].size) : 0
        data.delete(:order_times)
        data.delete(:fulfill_times)
      end

      # Only return regions with orders
      regional_data.select { |_, data| data[:pc] > 0 || data[:ac] > 0 }
    end

    def generate_type_stats(scope)
      results = scope.group(:aasm_state)
                     .select(
                       :aasm_state,
                       "COUNT(*) as count",
                       "AVG(EXTRACT(EPOCH FROM (NOW() - shop_orders.created_at))) as avg_hours_since_order",
                       "AVG(EXTRACT(EPOCH FROM (NOW() - shop_orders.awaiting_periodical_fulfillment_at))) as avg_hours_since_fulfillment"
                     )
                     .index_by(&:aasm_state)

      pending = results["pending"]
      awaiting = results["awaiting_periodical_fulfillment"]

      {
        pc: pending&.count || 0,
        ac: awaiting&.count || 0,
        aho: pending&.avg_hours_since_order&.to_i || 0,
        ahf: awaiting&.avg_hours_since_fulfillment&.to_i || 0
      }
    end

    def ensure_authorized_user
      unless current_user&.admin?
        redirect_to root_path, alert: "whomp whomp"
      end
    end
  end
end

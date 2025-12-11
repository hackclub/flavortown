# frozen_string_literal: true

module Admin
  class FulfillmentDashboardController < ApplicationController
    before_action :ensure_authorized_user

    def index
      @fulfillment_type = params[:fulfillment_type] || "all"
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
        "hq_mail" => [ "ShopItem::HQMailItem", "ShopItem::PileOfStickersItem", "ShopItem::LetterMail" ],
        "third_party" => "ShopItem::ThirdPartyPhysical",
        "warehouse" => [ "ShopItem::WarehouseItem", "ShopItem::PileOfStickersItem" ],
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

    def base_fulfillment_scope(include_associations: false)
      scope = ShopOrder.where(aasm_state: [ "pending", "awaiting_periodical_fulfillment" ])
                       .where.not(shop_items: { type: "ShopItem::FreeStickers" })
                       .joins(:shop_item)

      if include_associations
        scope = scope.includes(:user, :shop_item)
                     .order(:awaiting_periodical_fulfillment_at, :created_at)
      end

      scope
    end

    def filtered_orders(fulfillment_type)
      base_scope = base_fulfillment_scope(include_associations: true)

      if fulfillment_type == "all" || !fulfillment_type_filters.key?(fulfillment_type)
        base_scope
      else
        shop_item_types = fulfillment_type_filters[fulfillment_type]
        base_scope.where(shop_items: { type: shop_item_types })
      end
    end

    def generate_statistics
      base_orders = base_fulfillment_scope

      @stats = {}

      fulfillment_type_filters.each do |type, shop_item_types|
        @stats[type.to_sym] = generate_type_stats(base_orders.where(shop_items: { type: shop_item_types }))
      end

      @stats[:all] = generate_type_stats(base_orders)
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

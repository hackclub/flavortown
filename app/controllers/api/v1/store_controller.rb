class Api::V1::StoreController < ApplicationController
  include ApiAuthenticatable

  class_attribute :response, default: {}

  self.response = {
    index: [
      {
        id: Integer,
        name: String,
        description: String,
        old_prices: Array,
        limited: "Boolean",
        stock: Integer,
        type: String,
        show_in_carousel: "Boolean",
        accessory_tag: String,
        agh_contents: Array,
        attached_shop_item_ids: Array,
        buyable_by_self: "Boolean",
        long_description: String,
        max_qty: Integer,
        one_per_person_ever: "Boolean",
        sale_percentage: Integer,
        image_url: String,

        enabled: {
          au: "Boolean",
          ca: "Boolean",
          eu: "Boolean",
          in: "Boolean",
          uk: "Boolean",
          us: "Boolean",
          xx: "Boolean"
        },

        ticket_cost: {
          base_cost: Integer,
          au: Integer,
          ca: Integer,
          eu: Integer,
          in: Integer,
          uk: Integer,
          us: Integer,
          xx: Integer
        }
      }
    ],

    show: {
      id: Integer,
      name: String,
      description: String,
      old_prices: Array,
      limited: "Boolean",
      stock: Integer,
      type: String,
      show_in_carousel: "Boolean",
      accessory_tag: String,
      agh_contents: Array,
      attached_shop_item_ids: Array,
      buyable_by_self: "Boolean",
      long_description: String,
      max_qty: Integer,
      one_per_person_ever: "Boolean",
      sale_percentage: Integer,
      image_url: String,

      enabled: {
        au: "Boolean",
        ca: "Boolean",
        eu: "Boolean",
        in: "Boolean",
        uk: "Boolean",
        us: "Boolean",
        xx: "Boolean"
      },

      ticket_cost: {
        base_cost: Integer,
        au: Integer,
        ca: Integer,
        eu: Integer,
        in: Integer,
        uk: Integer,
        us: Integer,
        xx: Integer
      }
    }
  }

  def index
    @items = ShopItem.enabled
  end

  def show
    @item = ShopItem.enabled.find_by!(id: params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Item not found" }, status: :not_found
  end
end

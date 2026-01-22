class Api::V1::StoreController < Api::BaseController
  include ApiAuthenticatable

  class_attribute :description, default: {
    index: "Fetch a list of store items. Ratelimit: 5 reqs/min",
    show: "Fetch a specific store item by ID. Ratelimit: 30 reqs/min"
  }

  response = {
      id: Integer,
      name: String,
      description: String,
      old_prices: Array,
      limited: "Boolean",
      stock: Integer,
      type: String,
      show_in_carousel: "Boolean",
      accessory_tag: String,
      agh_contents: "String || JSON",
      attached_shop_item_ids: Array,
      buyable_by_self: "Boolean",
      long_description: String,
      max_qty: Integer,
      one_per_person_ever: "Boolean",
      sale_percentage: Integer,
      image_url: String,

      enabled: {
        enabled_au: "Boolean",
        enabled_ca: "Boolean",
        enabled_eu: "Boolean",
        enabled_in: "Boolean",
        enabled_uk: "Boolean",
        enabled_us: "Boolean",
        enabled_xx: "Boolean"
      },

      ticket_cost: {
        base_cost: Float,
        au: Float,
        ca: Float,
        eu: Float,
        in: Float,
        uk: Float,
        us: Float,
        xx: Float
      }
    }

  class_attribute :response_body_model, default: {
    index: [ response ],

    show: response
  }

  def index
    @items = ShopItem.enabled.listed.includes(image_attachment: :blob)
  end

  def show
    @item = ShopItem.enabled.find_by!(id: params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Item not found" }, status: :not_found
  end
end

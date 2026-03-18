class Api::V1::StoreController < Api::BaseController
  include ApiAuthenticatable

  before_action :open!

  class_attribute :description, default: {
    index: "Fetch a list of store items. Ratelimit: 5 reqs/min",
    show: "Fetch a specific store item by ID. Ratelimit: 30 reqs/min",
    search: "Semantic search across store items using vector search + reranking. Ratelimit: 20 reqs/min"
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
      requires_achievement: "String || Null",
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

  SEARCH_ITEM_SCHEMA = {
    id: Integer,
    name: String,
    description: String,
    limited: "Boolean",
    stock: Integer,
    type: String,
    long_description: String,
    sale_percentage: Integer,
    image_url: "String || Null",
    ticket_cost: Integer
  }.freeze

  class_attribute :response_body_model, default: {
    index: [ response ],
    show: response,
    search: { results: [ SEARCH_ITEM_SCHEMA ], query: String, count: Integer }
  }

  def index
    @items = ShopItem.enabled.listed.includes(image_attachment: :blob)
  end

  def search
    return render json: { error: "Search is not enabled. Set FERRET=true to activate." }, status: :service_unavailable unless ENV["FERRET"].present?
    return render json: { error: "q parameter is required" }, status: :bad_request if params[:q].blank?

    limit = (params[:limit] || 20).to_i.clamp(1, 50)
    @results = ShopItem.ferret_search(params[:q], limit: limit)
    @results = @results.select { |item| item.enabled? && !item.unlisted? }
  end

  def show
    @item = ShopItem.enabled.listed.find_by!(id: params[:id])
  end

  private

  def open!
    unless Flipper.enabled?(:shop_open)
      render json: { error: "Shop is currently closed" }, status: :service_unavailable
    end
  end
end

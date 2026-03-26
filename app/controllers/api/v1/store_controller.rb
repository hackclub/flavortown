class Api::V1::StoreController < Api::BaseController
  include ApiAuthenticatable

  before_action :open!

  def index
    @items = ShopItem.enabled.listed.includes(image_attachment: :blob)
  end

  def search
    return render json: { error: "Search is not enabled. Set FERRET=true to activate." }, status: :service_unavailable unless ENV["FERRET"].present?
    return render json: { error: "q parameter is required" }, status: :bad_request if params[:q].blank?

    limit = (params[:limit] || 20).to_i
    return render json: { error: "Limit must be between 1 and 50" }, status: :bad_request if limit < 1 || limit > 50

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

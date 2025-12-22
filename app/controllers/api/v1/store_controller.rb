class Api::V1::StoreController < ApplicationController
  include ApiAuthenticatable

  def index
    @items = ShopItem.enabled
  end

  def show
    @item = ShopItem.enabled.find_by!(id: params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Item not found" }, status: :not_found
  end
end

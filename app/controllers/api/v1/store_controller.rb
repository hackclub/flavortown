class Api::V1::StoreController < ApplicationController
  include ApiAuthenticatable

  def index
    @items = ShopItem.where(enabled: true)
  end

  def show
    @item = ShopItem.find_by!(id: params[:id], enabled: true)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Item not found" }, status: :not_found
  end
end

module Api::V1::StoreController < ApplicationController
  def index
    @items = ShopItem.where(enabled: true)
  end

  def show
    @item = ShopItem.find_by!(id: params[:id], enabled: true)
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
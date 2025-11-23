class ShopController < ApplicationController
  def index
    @shop_open = true
    @featured_item = ShopItem.where(type: "ShopItem::FreeStickers").includes(:image_attachment).first
    @shop_items = ShopItem.all.includes(:image_attachment)
  end

  def my_orders
    @orders = current_user.shop_orders.includes(:shop_item)
  end
end

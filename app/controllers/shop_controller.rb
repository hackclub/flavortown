class ShopController < ApplicationController
  def index
    @shop_open = true
    @weekly_item = ShopItem.shown_in_carousel.includes(:image_attachment).first
    @shop_items = ShopItem.all.includes(:image_attachment)
  end

  def my_orders
    @orders = current_user.shop_orders.includes(:shop_item)
  end
end

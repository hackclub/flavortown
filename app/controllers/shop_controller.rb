class ShopController < ApplicationController
  def index
    @shop_open = true
  end

  def my_orders
    @orders = current_user.shop_orders.includes(:shop_item)
  end
end

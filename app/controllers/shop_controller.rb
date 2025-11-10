class ShopController < ApplicationController
  def index
    @shop_open = Flipper.enabled?(:shop_open, current_user)
  end
end

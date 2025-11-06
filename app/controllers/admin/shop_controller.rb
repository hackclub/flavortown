module Admin
  class ShopController < Admin::ApplicationController
    def index
      authorize :admin, :manage_shop?
      @shop_items = ShopItem.order(created_at: :desc).limit(20)
    end
  end
end

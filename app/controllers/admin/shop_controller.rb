module Admin
  class ShopController < Admin::ApplicationController
    def index
      authorize :admin, :manage_shop?
      @shop_items = ShopItem.order(created_at: :desc).limit(20)
    end

    def clear_carousel_cache
      authorize :admin, :manage_shop?
      Rails.cache.delete(Cache::CarouselPrizesJob::CACHE_KEY)
      redirect_to admin_manage_shop_path, notice: "Carousel cache cleared successfully."
    end
  end
end

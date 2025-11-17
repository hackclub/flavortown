class Cache::CarouselPrizesJob < ApplicationJob
  queue_as :literally_whenever

  CACHE_KEY = "landing_carousel_prizes"
  CACHE_DURATION = 1.hour

  def perform(force: false)
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_DURATION, force: force) do
      ShopItem.with_attached_image
              .shown_in_carousel
              .order(:ticket_cost)
              .map do |prize|
        {
          id: prize.id,
          name: prize.name,
          hours_estimated: prize.hours_estimated,
          has_image: prize.image.attached?
        }
      end
    end
  end
end

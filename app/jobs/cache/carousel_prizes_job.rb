class Cache::CarouselPrizesJob < ApplicationJob
  queue_as :literally_whenever

  CACHE_KEY = "landing_carousel_prizes"
  CACHE_DURATION = 1.hour

  def perform(force: false)
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_DURATION, force: force) do
      ShopItem.includes(image_attachment: { blob: :variant_records })
              .shown_in_carousel
              .order(:ticket_cost)
              .map do |prize|
        {
          id: prize.id,
          name: prize.name,
          hours_estimated: prize.hours_estimated,
          image_url: prize.image.present? ? prize.image.url(expires_in: 1.week) : nil
        }
      end
    end
  end
end

class Cache::CarouselPrizesJob < ApplicationJob
  include Rails.application.routes.url_helpers

  queue_as :literally_whenever

  CACHE_KEY = "landing_carousel_prizes"
  CACHE_DURATION = 1.hour

  def perform(force: false)
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_DURATION, force: force) do
      ShopItem.with_attached_image
              .shown_in_carousel
              .order(:ticket_cost)
              .map do |prize|
        urls = if prize.image.attached?
          {
            sm: rails_blob_url(prize.image.variant(:carousel_sm), expires_in: CACHE_DURATION + 10.seconds),
            md: rails_blob_url(prize.image.variant(:carousel_md), expires_in: CACHE_DURATION + 10.seconds),
            lg: rails_blob_url(prize.image.variant(:carousel_lg), expires_in: CACHE_DURATION + 10.seconds),
            original: rails_blob_url(prize.image, expires_in: CACHE_DURATION + 10.seconds)
          }
        end

        {
          id: prize.id,
          name: prize.name,
          hours_estimated: prize.hours_estimated,
          image_url: urls&.[](:md),
          srcset: urls && "#{urls[:sm]} 160w, #{urls[:md]} 240w, #{urls[:lg]} 360w, #{urls[:original]} 800w"
        }
      end
    end
  end
end

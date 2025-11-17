class Cache::CarouselPrizesJob < ApplicationJob
  queue_as :literally_whenever

  CACHE_KEY = "landing_carousel_prizes"
  CACHE_DURATION = 1.hour

  def perform(force: false)
    # Set URL options for ActiveStorage URL generation in background job
    url_options = Rails.application.config.action_mailer.default_url_options.dup
    url_options[:protocol] = Rails.env.production? ? "https" : "http"
    ActiveStorage::Current.url_options = url_options

    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_DURATION, force: force) do
      ShopItem.with_attached_image
              .shown_in_carousel
              .order(:ticket_cost)
              .map do |prize|
        variant_urls =
          if prize.image.attached?
            {
              sm: prize.image.variant(:carousel_sm).processed.url,
              md: prize.image.variant(:carousel_md).processed.url,
              lg: prize.image.variant(:carousel_lg).processed.url,
              original: prize.image.url
            }
          else
            nil
          end

        {
          id: prize.id,
          name: prize.name,
          hours_estimated: prize.hours_estimated,
          image_url: prize.image.attached? ? prize.image.url : nil,
          image_variants: variant_urls
        }
      end
    end
  end
end

class Cache::CarouselPrizesJob < ApplicationJob
  queue_as :literally_whenever

  CACHE_KEY      = "landing_carousel_prizes"
  CACHE_DURATION = 1.hour

  def perform(force: false)
    url_options = Rails.application.config.action_mailer.default_url_options.dup
    url_options[:protocol] ||= Rails.env.production? ? "https" : "http"

    ActiveStorage::Current.url_options = url_options

    url_helpers = Rails.application.routes.url_helpers

    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_DURATION, force: force) do
      ShopItem.with_attached_image
              .shown_in_carousel
              .order(:ticket_cost)
              .map do |prize|
        if prize.image.attached?
          sm_variant = prize.image.variant(:carousel_sm).processed
          md_variant = prize.image.variant(:carousel_md).processed
          lg_variant = prize.image.variant(:carousel_lg).processed

          variant_urls = {
            sm: url_helpers.rails_representation_url(sm_variant, **url_options),
            md: url_helpers.rails_representation_url(md_variant, **url_options),
            lg: url_helpers.rails_representation_url(lg_variant, **url_options),
            original: url_helpers.rails_blob_url(prize.image, **url_options)
          }
        else
          variant_urls = nil
        end

        {
          id: prize.id,
          name: prize.name,
          hours_estimated: prize.hours_estimated,
          image_url: prize.image.attached? ? url_helpers.rails_blob_url(prize.image, **url_options) : nil,
          image_variants: variant_urls
        }
      end
    end
  end
end

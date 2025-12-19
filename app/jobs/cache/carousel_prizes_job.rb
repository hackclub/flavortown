class Cache::CarouselPrizesJob < ApplicationJob
  queue_as :literally_whenever

  CACHE_KEY = "landing_carousel_prizes"
  CACHE_DURATION = 1.hour

  def perform(force: false)
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_DURATION, force: force) do
      build_prizes_data
    end
  end

  private

  def build_prizes_data
    ShopItem.with_attached_image
            .shown_in_carousel
            .order(:ticket_cost)
            .select { |prize| prize.image.attached? }
            .map { |prize| build_prize_hash(prize) }
  end

  def build_prize_hash(prize)
    sm, md, lg, original = generate_image_urls(prize)

    {
      id: prize.id,
      name: prize.name,
      hours_estimated: prize.hours_estimated,
      image_src: md || sm || lg || original,
      image_srcset: build_srcset(sm, md, lg, original)
    }
  end

  def generate_image_urls(prize)
    url_options = { expires_in: CACHE_DURATION + 1.hour }

    [
      url_for_variant(prize.image.variant(:carousel_sm), url_options),
      url_for_variant(prize.image.variant(:carousel_md), url_options),
      url_for_variant(prize.image.variant(:carousel_lg), url_options),
      url_for_blob(prize.image, url_options)
    ]
  end

  def url_for_variant(variant, options)
    Rails.application.routes.url_helpers.rails_representation_path(
      variant.processed,
      only_path: true,
      **options
    )
  end

  def url_for_blob(blob, options)
    Rails.application.routes.url_helpers.rails_blob_path(
      blob,
      only_path: true,
      **options
    )
  end

  def build_srcset(sm, md, lg, original)
    [
      ("#{sm} 160w" if sm),
      ("#{md} 240w" if md),
      ("#{lg} 360w" if lg),
      ("#{original} 800w" if original)
    ].compact.join(", ").presence
  end
end

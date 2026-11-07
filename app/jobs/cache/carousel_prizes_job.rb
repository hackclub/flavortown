class Cache::CarouselPrizesJob < ApplicationJob
  queue_as :literally_whenever

  CACHE_KEY = "landing_carousel_prizes"

  def self.fetch(force: false)
    Rails.cache.fetch(CACHE_KEY, force: force) do
      new.send(:build_prizes_data)
    end
  end

  def perform(force: false)
    Rails.cache.fetch(CACHE_KEY, force: force) do
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
    sm, md, lg = generate_image_urls(prize)

    {
      id: prize.id,
      name: prize.name,
      hours_estimated: prize.hours_estimated,
      image_src: md || sm || lg,
      image_srcset: build_srcset(sm, md, lg)
    }
  end

  def generate_image_urls(prize)
    [
      url_for_variant(prize.image.variant(:carousel_sm)),
      url_for_variant(prize.image.variant(:carousel_md)),
      url_for_variant(prize.image.variant(:carousel_lg))
    ]
  end

  def url_for_variant(variant)
    Rails.application.routes.url_helpers.rails_representation_path(variant.processed, only_path: true)
  end

  def build_srcset(sm, md, lg)
    [
      ("#{sm} 160w" if sm),
      ("#{md} 240w" if md),
      ("#{lg} 360w" if lg)
    ].compact.join(", ").presence
  end
end

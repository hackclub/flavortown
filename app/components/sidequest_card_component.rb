# frozen_string_literal: true

class SidequestCardComponent < ViewComponent::Base
  VARIANTS = %i[blue green red].freeze

  attr_reader :title, :description, :variant, :learn_more_link, :submit_link

  def initialize(title:, image:, sticker_image: nil, description:, learn_more_link:, submit_link:, variant: :red)
    @title = title
    @image_path = image
    @sticker_image_path = sticker_image
    @description = description
    @learn_more_link = learn_more_link
    @submit_link = submit_link
    @variant = variant
  end

  def banner_image_url
    helpers.image_path(@banner_image_path)
  end

  def image_url
    helpers.image_path(@image_path)
  end

  def sticker_image_url
    helpers.image_path(@sticker_image_path) if @sticker_image_path.present?
  end

  def card_classes
    "sidequest-card sidequest-card--#{variant}"
  end
end

# frozen_string_literal: true

class SidequestCardComponent < ViewComponent::Base
  VARIANTS = %i[blue green red].freeze

  attr_reader :title, :description, :variant, :button_one_text, :button_one_link, :button_two_text, :button_two_link

  def initialize(title:, image:, sticker_image: nil, description:, button_one_text: nil, button_one_link: nil, button_two_text: nil, button_two_link: nil, variant: :red)
    @title = title
    @image_path = image
    @sticker_image_path = sticker_image
    @description = description
    @button_one_text = button_one_text
    @button_one_link = button_one_link
    @button_two_text = button_two_text
    @button_two_link = button_two_link
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

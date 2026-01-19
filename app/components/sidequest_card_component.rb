# frozen_string_literal: true

class SidequestCardComponent < ViewComponent::Base
  VARIANTS = %i[purple blue green red].freeze

  attr_reader :description, :variant, :learn_more_link, :submit_link

  def initialize(banner_image:, image:, description:, learn_more_link:, submit_link:, variant: :purple)
    @banner_image_path = banner_image
    @image_path = image
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

  def card_classes
    "sidequest-card sidequest-card--#{variant}"
  end
end

# frozen_string_literal: true

class SidequestCardComponent < ViewComponent::Base
  VARIANTS = %i[blue green red].freeze

  attr_reader :title, :description, :variant, :learn_more_link, :submit_link, :expires_at

  def initialize(title:, image:, sticker_image: nil, description:, learn_more_link:, submit_link:, variant: :red, expires_at: nil)
    @title = title
    @image_path = image
    @sticker_image_path = sticker_image
    @description = description
    @learn_more_link = learn_more_link
    @submit_link = submit_link
    @variant = variant
    @expires_at = expires_at
  end

  def expired?
    expires_at.present? && expires_at < Date.current
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
    classes = [ "sidequest-card", "sidequest-card--#{variant}" ]
    classes << "sidequest-card--expired" if expired?
    classes.join(" ")
  end
end

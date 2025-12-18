class StarterProjectCardComponent < ViewComponent::Base
  include MarkdownHelper

  attr_reader :name, :description, :image_url, :image_bg_color, :image_bg_image, :featured

  def initialize(name:, description:, image_url:, image_bg_color: "#AB5A07", image_bg_image: nil, featured: false)
    @name = name
    @description = description
    @image_url = image_url
    @image_bg_color = image_bg_color
    @image_bg_image = image_bg_image
    @featured = featured
  end
end

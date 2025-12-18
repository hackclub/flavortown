class DialogueBoxComponent < ViewComponent::Base
  include ActionView::Helpers::AssetUrlHelper

  attr_reader :text, :sticker, :sticker_line_index, :redirect_url

  def initialize(text:, button_text: "Continue", sticker: nil, show_sticker: false, sticker_line_index: 2, redirect_url: nil)
    @text = text.is_a?(Array) ? text : [ text ]
    @sticker = if sticker.present?
      sticker
    elsif show_sticker
      "free_sticker.png"
    end
    @sticker_line_index = sticker_line_index
    @redirect_url = redirect_url
  end

  def sprite_urls
    (1..12).map { |i| helpers.image_path("orpheus_sprites/#{i}.png") }
  end
end

class DialogueBoxComponent < ViewComponent::Base
  include ActionView::Helpers::AssetUrlHelper

  attr_reader :text, :show_sticker

  def initialize(text:, button_text: "Continue", show_sticker: false)
    @text = text.is_a?(Array) ? text : [ text ]
    @show_sticker = show_sticker
  end

  def sprite_urls
    (1..12).map { |i| helpers.image_path("orpheus_sprites/#{i}.png") }
  end
end

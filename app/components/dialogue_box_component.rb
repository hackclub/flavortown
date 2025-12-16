class DialogueBoxComponent < ViewComponent::Base
  attr_reader :text, :show_sticker

  def initialize(text:, button_text: "Continue", show_sticker: false)
    @text = text.is_a?(Array) ? text : [ text ]
    @show_sticker = show_sticker
  end
end

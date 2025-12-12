class DialogueBoxComponent < ViewComponent::Base
  attr_reader :text

  def initialize(text:, button_text: "Continue")
    @text = text.is_a?(Array) ? text : [ text ]
  end
end

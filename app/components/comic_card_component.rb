# frozen_string_literal: true

class ComicCardComponent < ViewComponent::Base
  attr_reader :image, :alt, :caption, :modal_title, :modal_text, :step_num, :modal_id

  def initialize(image:, alt:, caption:, modal_title:, modal_text:, step_num: nil)
    @image = image
    @alt = alt
    @caption = caption
    @modal_title = modal_title
    @modal_text = modal_text
    @step_num = step_num
    @modal_id = "comic-modal-#{object_id}"
  end

  def image_url
    helpers.image_path(image)
  end

  def modal_text_html
    helpers.sanitize(
      modal_text.to_s,
      tags: %w[a br strong em u p ul ol li b],
      attributes: %w[href target rel]
    )
  end
end

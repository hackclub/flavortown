# frozen_string_literal: true

class PopoverComponent < ViewComponent::Base
  POSITIONS = %i[top bottom left right].freeze

  renders_one :trigger
  renders_one :popover_content

  attr_reader :position, :html_options

  def initialize(position: :top, **html_options)
    @position = POSITIONS.include?(position.to_sym) ? position.to_sym : :top
    @html_options = html_options
  end

  def wrapper_classes
    class_names(
      "popover-wrapper",
      html_options[:class]
    )
  end

  def popover_classes
    class_names(
      "popover",
      "popover--#{position}"
    )
  end
end

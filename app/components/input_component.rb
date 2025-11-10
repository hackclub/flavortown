# frozen_string_literal: true

class InputComponent < ViewComponent::Base
  COLORS = %i[red blue green yellow].freeze

  attr_reader :label, :placeholder, :color, :subtitle

  def initialize(label:, placeholder:, color: :yellow, subtitle: nil)
    @label = label
    @placeholder = placeholder
    @color = normalize(:color, color, COLORS)
    @subtitle = subtitle
  end

  def input_classes
    class_names(
      "input",
      "input--#{color}"
    )
  end

  def has_subtitle?
    subtitle.present?
  end

  private

  def normalize(name, value, allowed)
    symbolized = value.to_sym
    return symbolized if allowed.include?(symbolized)

    raise ArgumentError,
          "#{name} must be one of #{allowed.join(', ')}, got #{value.inspect}"
  end
end

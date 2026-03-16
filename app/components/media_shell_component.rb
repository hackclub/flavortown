# frozen_string_literal: true

class MediaShellComponent < ViewComponent::Base
  COLORS = InputComponent::COLORS

  renders_one :label
  renders_one :body

  attr_reader :color, :subtitle

  def initialize(color: :green, subtitle: nil)
    @color = normalize_color(color)
    @subtitle = subtitle
  end

  def wrapper_classes
    class_names("input", "file-upload", "input--#{color}")
  end

  private

  def normalize_color(value)
    symbolized = value.to_sym
    return symbolized if COLORS.include?(symbolized)

    raise ArgumentError, "color must be one of #{COLORS.join(', ')}, got #{value.inspect}"
  end
end

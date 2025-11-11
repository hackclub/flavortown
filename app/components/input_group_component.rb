# frozen_string_literal: true

class InputGroupComponent < ViewComponent::Base
  COLORS = %i[red blue green yellow].freeze

  attr_reader :label, :color, :subtitle

  def initialize(label:, color: :blue, subtitle: nil)
    @label = label
    @color = normalize_color(color)
    @subtitle = subtitle
  end

  def group_classes
    "input-group input-group--#{color}"
  end

  def has_subtitle?
    subtitle.present?
  end

  private

  def normalize_color(value)
    symbolized = value.to_sym
    return symbolized if COLORS.include?(symbolized)

    raise ArgumentError, "color must be one of #{COLORS.join(', ')}, got #{value.inspect}"
  end
end

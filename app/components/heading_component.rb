# frozen_string_literal: true

class HeadingComponent < ViewComponent::Base
  TONES = %i[brown red green blue].freeze
  SIZES = %i[default full].freeze

  attr_reader :title, :tone, :size

  def initialize(title:, tone: :brown, size: :default)
    @title = title
    @tone = normalize(:tone, tone, TONES)
    @size = normalize(:size, size, SIZES)
  end

  def heading_classes
    class_names(
      "ui-heading",
      "ui-heading--#{tone}": tone != :brown,
      "ui-heading--full": size == :full
    )
  end

  private

  def normalize(name, value, allowed)
    symbolized = value.to_sym
    return symbolized if allowed.include?(symbolized)

    raise ArgumentError,
          "#{name} must be one of #{allowed.join(', ')}, got #{value.inspect}"
  end
end

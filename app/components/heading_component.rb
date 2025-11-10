# frozen_string_literal: true

class HeadingComponent < ViewComponent::Base
  TONES = %i[brown red green blue].freeze

  attr_reader :title, :tone

  def initialize(title:, tone: :brown)
    @title = title
    @tone = normalize(:tone, tone, TONES)
  end

  def heading_classes
    class_names(
      "ui-heading",
      "ui-heading--#{tone}": tone != :brown
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

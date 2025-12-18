class ProjectSelectionCardComponent < ViewComponent::Base
  VARIANTS = %i[blue yellow red green].freeze

  def initialize(title:, description:, image_url:, variant: :blue)
    @title = title
    @description = description
    @image_url = image_url
    @variant = normalize_variant(variant)
  end

  private

  def normalize_variant(value)
    symbol = value.to_sym
    return symbol if VARIANTS.include?(symbol)

    raise ArgumentError, "variant must be one of #{VARIANTS.join(', ')}, got #{value.inspect}"
  end
end

# frozen_string_literal: true

class ButtonComponent < ViewComponent::Base
  COLORS = %i[red green blue yellow brown bg_yellow].freeze
  VARIANTS = %i[default striped borderless].freeze
  SIZES = %i[sm md lg].freeze

  attr_reader :text, :color, :variant, :size, :icon, :type, :href, :method, :disable_with, :html_options

  def initialize(
    text: nil,
    color: :red,
    variant: :default,
    icon: nil,
    size: :md,
    type: :button,
    href: nil,
    method: nil,
    disable_with: nil,
    **html_options
  )
    @text = text
    @color = normalize(:color, color, COLORS)
    @variant = normalize(:variant, variant, VARIANTS)
    @icon = icon
    @size = normalize(:size, size, SIZES)
    @type = type
    @href = href
    @method = method
    @disable_with = disable_with
    @html_options = html_options
  end

  def button_classes
    classes = {
      "btn" => true,
      "btn--#{color}" => color.present?,
      "btn--#{variant}" => variant != :default,
      "btn--#{size}" => size != :md
    }
    class_names(classes, html_options[:class])
  end

  def button_attributes
    attrs = html_options.except(:class).merge(class: button_classes)
    if disable_with.present? && type == :submit
      attrs[:data] ||= {}
      attrs[:data][:turbo_submits_with] = disable_with
    end
    attrs
  end

  def link_attributes
    attrs = button_attributes
    if method.present? && method.to_sym != :get
      attrs[:data] ||= {}
      attrs[:data][:turbo_method] = method
    end
    attrs
  end

  def icon_tag
    return nil unless icon.present?
    return helpers.inline_svg_tag(icon) if icon.end_with?(".svg")
    return helpers.image_tag(icon) if icon.match?(/\.(webp|png|jpg|jpeg|gif)/i)
    icon
  end

  def display_text
    text || ""
  end

  def is_link?
    href.present?
  end

  def is_striped?
    variant == :striped
  end

  private

  def normalize(name, value, allowed)
    symbolized = value.to_sym
    return symbolized if allowed.include?(symbolized)

    raise ArgumentError,
          "#{name} must be one of #{allowed.join(', ')}, got #{value.inspect}"
  end
end

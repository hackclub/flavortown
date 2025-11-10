# frozen_string_literal: true

class InputComponent < ViewComponent::Base
  COLORS = %i[red blue green yellow].freeze

  attr_reader :label, :placeholder, :color, :subtitle, :form, :attribute

  def initialize(label:, placeholder:, form:, attribute:, color: :yellow, subtitle: nil, as: :text_field, input_html: {})
    @label = label
    @placeholder = placeholder
    @form = form
    @attribute = attribute
    @color = normalize_color(color)
    @subtitle = subtitle
    @field_method = normalize_field_method(as)
    @input_html = input_html.to_h
  end

  def input_classes
    class_names("input", "input--#{color}")
  end

  def field_tag
    form.public_send(field_method, attribute, field_options)
  end

  def has_subtitle?
    subtitle.present?
  end

  private

  attr_reader :field_method, :input_html

  def field_options
    options = input_html.dup
    options[:placeholder] ||= placeholder
    options[:class] = class_names("input__field", ("input__field--textarea" if field_method == :text_area), options[:class])
    options[:rows] ||= 5 if field_method == :text_area
    options
  end

  def normalize_color(value)
    symbolized = value.to_sym
    return symbolized if COLORS.include?(symbolized)

    raise ArgumentError, "color must be one of #{COLORS.join(', ')}, got #{value.inspect}"
  end

  def normalize_field_method(value)
    method = value.to_sym
    return :text_area if method == :textarea
    return method if %i[text_field text_area].include?(method)

    raise ArgumentError, "Unsupported field type #{value.inspect}"
  end
end

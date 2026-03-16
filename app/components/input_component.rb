# frozen_string_literal: true

class InputComponent < ViewComponent::Base
  COLORS = %i[red blue green yellow brown].freeze

  attr_reader :label, :placeholder, :color, :subtitle, :form, :attribute, :collection, :icon

  def initialize(label:, placeholder:, form:, attribute:, color: :yellow, subtitle: nil, icon: nil, as: :text_field, input_html: {}, collection: nil, select_options: {})
    @label = label
    @placeholder = placeholder
    @form = form
    @attribute = attribute
    @color = normalize_color(color)
    @subtitle = subtitle
    @icon = icon
    @field_method = normalize_field_method(as)
    @input_html = input_html.to_h
    @collection = collection
    @select_options = select_options.to_h

    validate_configuration!
  end

  def input_classes
    class_names("input", "input--#{color}", "input--with-icon" => icon.present?)
  end

  def field_tag
    case field_method
    when :select
      form.select(attribute, collection, select_field_options, field_options)
    else
      form.public_send(field_method, attribute, field_options)
    end
  end

  def has_subtitle?
    subtitle.present?
  end

  def icon_tag
    return nil unless icon.present?
    return helpers.inline_svg_tag(icon) if icon.end_with?(".svg")
    icon
  end

  private

  attr_reader :field_method, :input_html, :select_options

  def field_options
    options = input_html.dup
    options[:placeholder] ||= placeholder if apply_placeholder_to_field?
    options[:class] = class_names("input__field", field_modifier_class, options[:class])
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
    return :select if method == :select
    return :number_field if method == :number_field
    return method if %i[text_field text_area number_field].include?(method)
    return method if %i[text_field text_area].include?(method)

    raise ArgumentError, "Unsupported field type #{value.inspect}"
  end

  def apply_placeholder_to_field?
    field_method != :select
  end

  def field_modifier_class
    case field_method
    when :text_area
      "input__field--textarea"
    when :select
      "input__field--select"
    end
  end

  def select_field_options
    return {} unless field_method == :select

    options = select_options.dup
    options[:prompt] = placeholder if placeholder.present? && !options.key?(:prompt) && !options.key?(:include_blank)
    options
  end

  def validate_configuration!
    return unless field_method == :select

    raise ArgumentError, "collection is required for select inputs" if collection.nil?
  end
end

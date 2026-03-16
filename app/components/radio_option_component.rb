# frozen_string_literal: true

class RadioOptionComponent < ViewComponent::Base
  attr_reader :name, :value, :label, :radiogroup, :checked

  def initialize(name:, value:, label:, radiogroup:, checked: false, **html_options)
    @name = name
    @value = value
    @label = label
    @radiogroup = radiogroup
    @checked = checked
    @html_options = html_options
  end

  def container_classes
    class_names(
      "radio-option",
      @html_options[:class]
    )
  end

  def input_id
    "#{name}_#{value}"
  end
end

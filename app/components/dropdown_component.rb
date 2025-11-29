class DropdownComponent < ViewComponent::Base
  attr_reader :label, :options, :selected_option, :color, :longest_option_string

  def initialize(label:, options:, selected_option:, longest_option_string:, color: :brown)
    @label = label
    @options = options
    @selected_option = selected_option
    @longest_option_string = longest_option_string
    @color = color
  end

  def dropdown_classes
    "dropdown dropdown--#{color}"
  end
end

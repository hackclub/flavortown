class DropdownComponent < ViewComponent::Base
  attr_reader :label, :options, :selected_option, :color

  def initialize(label:, options:, selected_option:, color: :brown)
    @label = label
    @options = options
    @selected_option = selected_option
    @color = color
  end

  def dropdown_classes
    "dropdown dropdown--#{color}"
  end
end

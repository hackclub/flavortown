class StateCardComponent < ViewComponent::Base
  def initialize(title:, description:, variant:, badge_text:, icon: nil)
    @title = title
    @description = description
    @variant = variant.to_sym
    @badge_text = badge_text
    @icon = icon
  end
end


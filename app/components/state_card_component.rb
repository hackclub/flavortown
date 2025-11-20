class StateCardComponent < ViewComponent::Base
  def initialize(title:, description:, variant:, badge_text:, icon: nil, cta_text: nil, cta_href: nil)
    @title = title
    @description = description
    @variant = variant.to_sym
    @badge_text = badge_text
    @icon = icon
    @cta_text = cta_text
    @cta_href = cta_href
  end
end

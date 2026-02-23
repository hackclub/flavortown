class PlatformNoticeComponent < ViewComponent::Base
  attr_reader :heading_element

  def initialize(heading_element: "h2")
    @heading_element = heading_element
  end
end

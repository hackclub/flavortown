class PlatformNoticeComponent < ViewComponent::Base
  attr_reader :heading_element, :with_margin, :title

  def initialize(title: "Voting is currently paused", heading_element: "h2", with_margin: false)
    @message_link = "https://hackclub.slack.com/archives/C09MATJJZ5J/p1771879301452079"
    @heading_element = heading_element
    @with_margin = with_margin
    @title = title
  end
end

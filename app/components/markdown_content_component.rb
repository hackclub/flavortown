class MarkdownContentComponent < ViewComponent::Base
  include MarkdownHelper

  def initialize(content:)
    @content = content
  end

  def render?
    @content.present?
  end
end

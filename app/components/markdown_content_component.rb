class MarkdownContentComponent < ViewComponent::Base
  include MarkdownHelper

  def initialize(markdown:)
    @markdown = markdown
  end

  def render?
    @markdown.present?
  end
end

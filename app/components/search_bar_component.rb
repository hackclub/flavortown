class SearchBarComponent < ViewComponent::Base
  def initialize(placeholder: "Search item", q: nil, action: nil)
    @placeholder = placeholder
    @q = q
    @action = action || "/search"
  end

  attr_reader :placeholder, :q, :action
end

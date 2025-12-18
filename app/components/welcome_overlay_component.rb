# frozen_string_literal: true

class WelcomeOverlayComponent < ViewComponent::Base
  include ActionView::Helpers::AssetUrlHelper
  include ActionView::Helpers::UrlHelper

  def initialize(redirect_to_shop_tutorial: false)
    @redirect_to_shop_tutorial = redirect_to_shop_tutorial
  end

  def shop_tutorial_url
    shop_path(tutorial: true)
  end

  private

  attr_reader :redirect_to_shop_tutorial
end

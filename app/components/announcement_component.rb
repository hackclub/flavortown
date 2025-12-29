class AnnouncementComponent < ViewComponent::Base
  attr_reader :title, :description, :image

  def initialize(title:, description:, image: nil)
    @title = title
    @description = description
    @image = image
  end
end
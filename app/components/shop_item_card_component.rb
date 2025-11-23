class ShopItemCardComponent < ViewComponent::Base
  attr_reader :name, :description, :hours, :price, :image_url

  def initialize(name:, description:, hours:, price:, image_url:)
    @name = name
    @description = description
    @hours = hours
    @price = price
    @image_url = image_url
  end
end

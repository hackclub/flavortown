class ShopItemCardComponent < ViewComponent::Base
  attr_reader :name, :description, :hours, :price, :image_url, :item_type

  def initialize(name:, description:, hours:, price:, image_url:, item_type: nil)
    @name = name
    @description = description
    @hours = hours
    @price = price
    @image_url = image_url
    @item_type = item_type
  end

  def show_customs_warning?
    return false unless item_type
    item_type.include?("HQMailItem") || item_type.include?("WarehouseItem")
  end
end

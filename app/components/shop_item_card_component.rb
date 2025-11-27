class ShopItemCardComponent < ViewComponent::Base
  attr_reader :item_id, :name, :description, :hours, :price, :image_url, :item_type

  def initialize(item_id:, name:, description:, hours:, price:, image_url:, item_type: nil)
    @item_id = item_id
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

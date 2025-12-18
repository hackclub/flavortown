class ShopItemCardComponent < ViewComponent::Base
  include MarkdownHelper

  attr_reader :item_id, :name, :description, :hours, :price, :image_url, :item_type, :balance, :enabled_regions, :regional_price, :logged_in

  def initialize(item_id:, name:, description:, hours:, price:, image_url:, item_type: nil, balance: nil, enabled_regions: [], regional_price: nil, logged_in: true)
    @item_id = item_id
    @name = name
    @description = description
    @hours = hours
    @price = price
    @image_url = image_url
    @item_type = item_type
    @balance = balance
    @enabled_regions = enabled_regions
    @regional_price = regional_price || price
    @logged_in = logged_in
  end

  def order_url
    logged_in ? "/shop/order?shop_item_id=#{item_id}" : "/"
  end

  def display_price
    @regional_price
  end

  def show_customs_warning?
    return false unless item_type
    item_type.include?("HQMailItem") || item_type.include?("WarehouseItem") || item_type.include?("ThirdPartyPhysical")
  end

  def categories
    return [] unless item_type
    cats = []
    case item_type
    when "ShopItem::HCBGrant", "ShopItem::HCBPreauthGrant"
      cats << "Grants" << "Digital"
    when "ShopItem::WarehouseItem", "ShopItem::HQMailItem", "ShopItem::LetterMail", "ShopItem::FreeStickers", "ShopItem::PileOfStickersItem"
      cats << "HQ"
    when "ShopItem::ThirdPartyDigital"
      cats << "Digital"
    when "ShopItem::ThirdPartyPhysical", "ShopItem::SpecialFulfillmentItem"
      cats << "Locally Fulfilled"
    when "ShopItem::HackClubberItem"
      cats << "Made by Hack Clubbers"
    end
    cats
  end
end

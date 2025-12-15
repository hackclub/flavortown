module ShopHelper
  PHYSICAL_ITEMS_WITH_CUSTOMS = %w[
    ShopItem::WarehouseItem
    ShopItem::HQMailItem
    ShopItem::HackClubberItem
    ShopItem::ThirdPartyPhysical
  ].freeze

  def should_show_customs_warning?(shop_item, address_country = nil)
    return false unless shop_item.present?

    case shop_item.type
    when "ShopItem::WarehouseItem", "ShopItem::ThirdPartyPhysical"
      address_country.present? && address_country != "United States"
    when "ShopItem::HQMailItem", "ShopItem::HackClubberItem"
      true
    else
      false
    end
  end

  def customs_warning_message(shop_item)
    case shop_item.type
    when "ShopItem::WarehouseItem"
      "⚠️ Shipped from US - Customs fees may apply if shipping outside the US"
    when "ShopItem::ThirdPartyPhysical"
      "⚠️ Shipped from US - Customs fees may apply if shipping outside the US"
    when "ShopItem::HQMailItem"
      "⚠️ Origin unknown - Customs fees may apply depending on destination country"
    when "ShopItem::HackClubberItem"
      "⚠️ Origin unknown - Customs fees may apply depending on destination country"
    end
  end

  def fulfillment_source_text(shop_item)
    case shop_item.type
    when "ShopItem::WarehouseItem"
      "Fulfilled by AGH Warehouse"
    when "ShopItem::HQMailItem"
      "Shipped from Hack Club HQ"
    when "ShopItem::HackClubberItem"
      "Made by Hack Clubber"
    when "ShopItem::HCBGrant", "ShopItem::HCBPreauthGrant"
      "Digital Grant"
    when "ShopItem::ThirdPartyDigital"
      "Third Party Digital"
    when "ShopItem::ThirdPartyPhysical"
      "Third Party Physical"
    when "ShopItem::FreeStickers"
      "Free Stickers"
    when "ShopItem::Accessory"
      "Accessory"
    else
      "Shop Item"
    end
  end

  def fulfillment_badge_color(shop_item)
    case shop_item.type
    when "ShopItem::WarehouseItem"
      "blue"
    when "ShopItem::HQMailItem"
      "red"
    when "ShopItem::HackClubberItem"
      "green"
    when "ShopItem::HCBGrant", "ShopItem::HCBPreauthGrant"
      "purple"
    when "ShopItem::ThirdPartyDigital", "ShopItem::ThirdPartyPhysical"
      "brown"
    when "ShopItem::FreeStickers"
      "tan"
    else
      "brown"
    end
  end

  def item_requires_address?(shop_item)
    PHYSICAL_ITEMS_WITH_CUSTOMS.include?(shop_item.type) || shop_item.type == "ShopItem::FreeStickers"
  end

  def is_warehouse_item?(shop_item)
    shop_item.type == "ShopItem::WarehouseItem"
  end

  def customs_warning_item_type(shop_item)
    case shop_item.type
    when "ShopItem::WarehouseItem", "ShopItem::ThirdPartyPhysical"
      "us_origin"
    when "ShopItem::HQMailItem", "ShopItem::HackClubberItem"
      "unknown_origin"
    else
      "none"
    end
  end
end

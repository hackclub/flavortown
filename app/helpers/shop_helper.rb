module ShopHelper
  PHYSICAL_ITEMS_WITH_CUSTOMS = %w[
    ShopItem::WarehouseItem
    ShopItem::HQMailItem
    ShopItem::HackClubberItem
    ShopItem::ThirdPartyPhysical
    ShopItem::Inkthreadable
  ].freeze

  def should_show_customs_warning?(shop_item, address_country = nil)
    return false unless shop_item.present?

    case shop_item.type
    when "ShopItem::WarehouseItem", "ShopItem::ThirdPartyPhysical"
      address_country.present? && address_country != "United States"
    when "ShopItem::HQMailItem", "ShopItem::HackClubberItem"
      true
    when "ShopItem::Inkthreadable"
      address_country.present? && address_country != "United Kingdom"
    else
      false
    end
  end

  def customs_warning_message(shop_item)
    case shop_item.type
    when "ShopItem::WarehouseItem"
      "⚠️ This item is shipped from the United States. Customs fees may apply if the destination country is not the United States."
    when "ShopItem::HQMailItem"
      "⚠️ This item is shipped from the United States. Customs fees may apply if the destination country is not the United States."
    when "ShopItem::HackClubberItem"
      "⚠️ Origin unknown - Customs fees may apply depending on destination country. Check the description for more details."
    when "ShopItem::Inkthreadable"
      "⚠️ This item is shipped from the United Kingdom. Customs fees may apply if the destination country is not the United Kingdom."
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
    when "ShopItem::WarehouseItem", "ShopItem::HQMailItem"
      "us_origin"
    when "ShopItem::Inkthreadable"
      "uk_origin"
    when "ShopItem::HackClubberItem"
      "unknown_origin"
    else
      "none"
    end
  end
end

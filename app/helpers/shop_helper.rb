module ShopHelper
  PHYSICAL_ITEMS_WITH_CUSTOMS = %w[
    ShopItem::WarehouseItem
    ShopItem::HQMailItem
    ShopItem::HackClubberItem
    ShopItem::ThirdPartyPhysical
    ShopItem::Inkthreadable
  ].freeze

  ITEMS_WITH_CONFIGURABLE_SOURCE_REGION = %w[
    ShopItem::HackClubberItem
    ShopItem::ThirdPartyDigital
    ShopItem::HQMailItem
  ].freeze

  def should_show_customs_warning?(shop_item, address_country = nil)
    return false unless shop_item.present?

    if shop_item.source_region.present? && ITEMS_WITH_CONFIGURABLE_SOURCE_REGION.include?(shop_item.type)
      return address_country.present? && !region_matches_country?(shop_item.source_region, address_country)
    end

    case shop_item.type
    when "ShopItem::WarehouseItem", "ShopItem::ThirdPartyPhysical"
      address_country.present? && address_country != "United States"
    when "ShopItem::HQMailItem"
      address_country.present? && address_country != "United States"
    when "ShopItem::HackClubberItem"
      true
    when "ShopItem::Inkthreadable"
      address_country.present? && address_country != "United Kingdom"
    else
      false
    end
  end

  def customs_warning_message(shop_item)
    if shop_item.source_region.present? && ITEMS_WITH_CONFIGURABLE_SOURCE_REGION.include?(shop_item.type)
      region_name = Shop::Regionalizable::REGIONS.dig(shop_item.source_region, :name) || shop_item.source_region
      return "⚠️ This item is shipped from #{region_name}. Customs fees may apply if the destination country is not in #{region_name}."
    end

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
    if shop_item.source_region.present? && ITEMS_WITH_CONFIGURABLE_SOURCE_REGION.include?(shop_item.type)
      return "custom_region"
    end

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

  def customs_warning_source_region(shop_item)
    shop_item.source_region if ITEMS_WITH_CONFIGURABLE_SOURCE_REGION.include?(shop_item.type)
  end

  private

  def region_matches_country?(region_code, country_name)
    region_config = Shop::Regionalizable::REGIONS[region_code]
    return false unless region_config

    country_codes = region_config[:countries]
    region_name = region_config[:name]

    country_name == region_name || country_codes.any? { |code| country_name_matches_code?(country_name, code) }
  end

  COUNTRY_CODES = {
    "US" => "United States",
    "GB" => "United Kingdom",
    "CA" => "Canada",
    "AU" => "Australia",
    "NZ" => "New Zealand",
    "IN" => "India",
    "DE" => "Germany",
    "FR" => "France",
    "IT" => "Italy",
    "ES" => "Spain",
    "NL" => "Netherlands",
    "BE" => "Belgium",
    "AT" => "Austria",
    "SE" => "Sweden",
    "DK" => "Denmark",
    "FI" => "Finland",
    "PL" => "Poland",
    "CZ" => "Czech Republic",
    "HU" => "Hungary",
    "GR" => "Greece",
    "PT" => "Portugal",
    "IE" => "Ireland",
    "RO" => "Romania",
    "BG" => "Bulgaria",
    "HR" => "Croatia",
    "SK" => "Slovakia",
    "SI" => "Slovenia",
    "LT" => "Lithuania",
    "LV" => "Latvia",
    "EE" => "Estonia",
    "CY" => "Cyprus",
    "MT" => "Malta",
    "LU" => "Luxembourg",
    "JP" => "Japan",
    "KR" => "South Korea",
    "CN" => "China",
    "BR" => "Brazil",
    "MX" => "Mexico",
    "SG" => "Singapore"
  }.freeze

  def country_name_from_code(code)
    COUNTRY_CODES[code&.upcase] || code
  end

  def country_name_matches_code?(country_name, country_code)
    country_name == COUNTRY_CODES[country_code]
  end
end

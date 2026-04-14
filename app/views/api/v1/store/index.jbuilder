json.array! @items do |item|
  json.extract! item, :id, :name, :description, :old_prices, :limited, :stock, :type, :show_in_carousel, :accessory_tag, :agh_contents, :attached_shop_item_ids, :buyable_by_self, :long_description, :max_qty, :one_per_person_ever, :sale_percentage, :requires_achievement

  if item.image.attached?
    json.image_url request.protocol + request.host + url_for(item.image)
  else
    json.image_url nil
  end

  json.enabled do
    json.extract! item, :enabled_au, :enabled_ca, :enabled_eu, :enabled_in, :enabled_uk, :enabled_us, :enabled_xx
  end

  json.ticket_cost do
    json.base_cost item.ticket_cost
    json.au item.base_price_for_region("AU")
    json.ca item.base_price_for_region("CA")
    json.eu item.base_price_for_region("EU")
    json.in item.base_price_for_region("IN")
    json.uk item.base_price_for_region("UK")
    json.us item.base_price_for_region("US")
    json.xx item.base_price_for_region("XX")
  end
end

json.array! @items do |item|
  json.extract! item, :id, :name, :description, :old_prices, :limited, :stock, :type, :show_in_carousel, :accessory_tag, :agh_contents, :attached_shop_item_ids, :buyable_by_self, :long_description, :max_qty, :one_per_person_ever, :sale_percentage

  if item.image.attached?
    json.image_url request.protocol + request.host + url_for(item.image)
  else
    json.image_url nil
  end

  json.enabled do
    json.extract! item, :au, :ca, :eu, :in, :uk, :us, :xx
  end

  json.ticket_cost do
    json.base_cost item.ticket_cost
    json.au item.ticket_cost + (item.price_offset_au || 0)
    json.ca item.ticket_cost + (item.price_offset_ca || 0)
    json.eu item.ticket_cost + (item.price_offset_eu || 0)
    json.in item.ticket_cost + (item.price_offset_in || 0)
    json.uk item.ticket_cost + (item.price_offset_uk || 0)
    json.us item.ticket_cost + (item.price_offset_us || 0)
    json.xx item.ticket_cost + (item.price_offset_xx || 0)
  end
end

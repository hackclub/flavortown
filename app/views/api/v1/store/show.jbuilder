json.extract! @item, :id, :name, :description, :old_prices, :limited, :stock, :type, :show_in_carousel, :accessory_tag, :agh_contents, :attached_shop_item_ids, :buyable_by_self, :long_description, :max_qty, :one_per_person_ever, :sale_percentage

if @item.image.attached?
  json.image_url request.protocol + request.host + url_for(@item.image)
else
  json.image_url nil
end

json.enabled do
  json.extract! @item, :enabled_au, :enabled_ca, :enabled_eu, :enabled_in, :enabled_uk, :enabled_us, :enabled_xx
end

json.ticket_cost do
  json.base_cost @item.ticket_cost.to_f
  json.au (@item.ticket_cost + (@item.price_offset_au || 0)).to_f
  json.ca (@item.ticket_cost + (@item.price_offset_ca || 0)).to_f
  json.eu (@item.ticket_cost + (@item.price_offset_eu || 0)).to_f
  json.in (@item.ticket_cost + (@item.price_offset_in || 0)).to_f
  json.uk (@item.ticket_cost + (@item.price_offset_uk || 0)).to_f
  json.us (@item.ticket_cost + (@item.price_offset_us || 0)).to_f
  json.xx (@item.ticket_cost + (@item.price_offset_xx || 0)).to_f
end

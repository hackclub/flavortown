json.extract! @item, :id, :name, :description, :old_prices, :limited, :stock, :type

if @item.image.attached?
  json.image_url request.protocol + request.host + url_for(@item.image)
else
  json.image_url nil
end

json.enabled do
  json.extract! @item, :enabled_au, :enabled_ca, :enabled_eu, :enabled_in, :enabled_uk, :enabled_us, :enabled_xx
end

json.ticket_cost do
  json.base_cost @item.ticket_cost
  json.au @item.ticket_cost + (@item.price_offset_au || 0)
  json.ca @item.ticket_cost + (@item.price_offset_ca || 0)
  json.eu @item.ticket_cost + (@item.price_offset_eu || 0)
  json.in @item.ticket_cost + (@item.price_offset_in || 0)
  json.uk @item.ticket_cost + (@item.price_offset_uk || 0)
  json.us @item.ticket_cost + (@item.price_offset_us || 0)
  json.xx @item.ticket_cost + (@item.price_offset_xx || 0)
end

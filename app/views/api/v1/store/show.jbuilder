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
  json.au @item.base_price_for_region("AU").to_f
  json.ca @item.base_price_for_region("CA").to_f
  json.eu @item.base_price_for_region("EU").to_f
  json.in @item.base_price_for_region("IN").to_f
  json.uk @item.base_price_for_region("UK").to_f
  json.us @item.base_price_for_region("US").to_f
  json.xx @item.base_price_for_region("XX").to_f
end

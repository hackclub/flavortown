json.items @items do |item|
  json.extract! item, :id, :name, :description, :ticket_cost, :old_prices, :limited, :stock, :type, :enabled_au, :enabled_ca, :enabled_eu, :enabled_in, :enabled_uk, :enabled_us, :enabled_xx

  if item.image.attached?
    json.image_url request.protocol + request.host + url_for(item.image)
  else
    json.image_url nil
  end
end

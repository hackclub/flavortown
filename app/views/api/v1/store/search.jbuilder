json.results @results do |item|
  json.extract! item, :id, :name, :description, :limited, :stock, :type, :long_description, :sale_percentage

  if item.image.attached?
    json.image_url request.protocol + request.host + url_for(item.image)
  else
    json.image_url nil
  end

  json.ticket_cost item.ticket_cost
end
json.query params[:q]
json.count @results.length

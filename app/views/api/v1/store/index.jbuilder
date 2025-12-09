json.items @items do |item|
  json.extract! item, :id, :name, :description, :ticket_cost, :old_prices, :limited, :stock, :type, :enabled_au, :enabled_ca, :enabled_eu, :enabled_in, :enabled_uk, :enabled_us, :enabled_xx
end

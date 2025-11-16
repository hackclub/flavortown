# db/seeds/shop_orders.rb
# Seeds 10-20 randomized shop orders with fake addresses for testing
# Usage:
# rails runner db/seeds/shop_orders.rb

require 'faker'

# Ensure shop items exist
shop_items = ShopItem.all
abort "No shop items found. Run shop item seeds first." if shop_items.empty?

# Ensure users exist
users = User.all
abort "No users found. Create some users first." if users.empty?

# Countries for fake addresses
COUNTRIES = ['US', 'CA', 'GB', 'AU', 'IN', 'DE', 'FR'].freeze

def generate_fake_address
  country = COUNTRIES.sample
  {
    "first_name" => Faker::Name.first_name,
    "last_name" => Faker::Name.last_name,
    "address_line_1" => Faker::Address.street_address,
    "address_line_2" => Faker::Address.secondary_address,
    "city" => Faker::Address.city,
    "state_province" => Faker::Address.state,
    "postal_code" => Faker::Address.postcode,
    "country" => country,
    "email" => Faker::Internet.email,
    "phone" => Faker::PhoneNumber.phone_number
  }
end

order_count = rand(10..20)
puts "Creating #{order_count} randomized shop orders..."

order_count.times do |index|
  user = users.sample
  shop_item = shop_items.sample
  quantity = rand(1..3)

  order = user.shop_orders.build(
    shop_item: shop_item,
    quantity: quantity,
    frozen_address: generate_fake_address,
    frozen_item_price: shop_item.ticket_cost || 100
  )

  if order.save
    puts "✓ Created order #{index + 1}/#{order_count} for #{user.display_name}"
  else
    puts "✗ Failed to create order #{index + 1}: #{order.errors.full_messages.join(', ')}"
  end
end

puts "Done seeding shop orders."

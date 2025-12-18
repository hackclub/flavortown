# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

free_stickers = ShopItem::FreeStickers.find_or_create_by!(name: "Free Stickers!") do |item|
  item.one_per_person_ever = true
  item.description = "we'll actually send you these!"
  item.ticket_cost = 10
  downloaded_image = URI.parse("https://hc-cdn.hel1.your-objectstorage.com/s/v3/4367d6fb4a3afa7b2e34ef63c13beaa33922f91b_untitled78_20251203024129__1_.png").open
  item.image.attach(io: downloaded_image, filename: "sticker.png")
end
free_stickers.update!(ticket_cost: 10) if free_stickers.ticket_cost != 10

user = User.find_or_create_by!(email: "max@hackclub.com", slack_id: "U09UQ385LSG")
user.make_super_admin!
user.make_admin!

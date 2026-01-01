class AddShipRequirementToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :requires_ship, :boolean, default: false
    add_column :shop_items, :required_ships_count, :integer, default: 1
    add_column :shop_items, :required_ships_start_date, :date
    add_column :shop_items, :required_ships_end_date, :date
  end
end

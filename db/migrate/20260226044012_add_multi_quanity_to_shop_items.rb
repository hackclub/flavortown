class AddMultiQuanityToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :multi_quantity_per_unit, :boolean, default: false
  end
end

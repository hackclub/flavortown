class AddOldPricesToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :old_prices, :integer, array: true, default: []
  end
end

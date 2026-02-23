class AddBlockedCountriesToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :blocked_countries, :string, array: true, default: []
  end
end

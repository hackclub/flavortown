class AddPastPurchasesToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :past_purchases, :integer, default: 0
  end
end

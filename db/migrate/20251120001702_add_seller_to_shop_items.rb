class AddSellerToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :shop_items, :user, null: true, foreign_key: true
    add_column :shop_items, :payout_percentage, :integer, default: 0
  end
end

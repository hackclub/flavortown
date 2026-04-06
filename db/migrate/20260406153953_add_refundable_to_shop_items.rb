class AddRefundableToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :refundable, :boolean, default: true
  end
end

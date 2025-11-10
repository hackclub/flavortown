class AddFrozenAddressCiphertextToShopOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_orders, :frozen_address_ciphertext, :text
  end
end

class AddFrozenAddressCiphertextToShopWarehousePackages < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_warehouse_packages, :frozen_address_ciphertext, :text
  end
end

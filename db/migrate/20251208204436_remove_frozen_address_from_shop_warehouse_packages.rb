class RemoveFrozenAddressFromShopWarehousePackages < ActiveRecord::Migration[8.1]
  def change
    remove_column :shop_warehouse_packages, :frozen_address, :jsonb
  end
end

class RenameWarehousePackagesToShopWarehousePackages < ActiveRecord::Migration[8.1]
  def change
    rename_table :warehouse_packages, :shop_warehouse_packages
  end
end

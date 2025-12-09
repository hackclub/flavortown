class IndexWarehousePackageOnShopOrder < ActiveRecord::Migration[8.1]
  def change
    add_index :shop_orders, :warehouse_package_id
    add_foreign_key :shop_orders, :shop_warehouse_packages, column: :warehouse_package_id
  end
end

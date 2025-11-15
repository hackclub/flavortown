module Shop
  class PackageBuilder
    # Batch orders together by assigning them the same warehouse_package_id
    # Uses the first order's ID as the package ID
    def self.build_for_user(user, orders)
      orders = Array(orders).select { |o| o.warehouse_package_id.nil? }
      return nil if orders.empty?

      # Use the first order's ID as the package ID
      package_id = orders.first.id
      ShopOrder.where(id: orders.map(&:id)).update_all(warehouse_package_id: package_id)
      
      package_id
    end

    # Build packages for all warehouse orders that are pending and don't have a package yet
    def self.batch_pending_warehouse_orders
      # Find all warehouse item orders that are pending and don't have a package
      orders = ShopOrder
        .joins(:shop_item)
        .where(shop_items: { type: "ShopItem::WarehouseItem" })
        .where(aasm_state: "pending")
        .where(warehouse_package_id: nil)
        .includes(:user, :shop_item)

      # Group by user
      orders_by_user = orders.group_by(&:user)

      package_ids = []
      orders_by_user.each do |user, user_orders|
        pkg_id = build_for_user(user, user_orders)
        package_ids << pkg_id if pkg_id
      end

      package_ids
    end
  end
end

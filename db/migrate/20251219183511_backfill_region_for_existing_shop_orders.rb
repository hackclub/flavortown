class BackfillRegionForExistingShopOrders < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    ShopOrder.where(region: nil).find_each do |order|
      order.send(:set_region_from_address)
      order.update_column(:region, order.region) if order.region.present?
    end
  end

  def down
    # No-op: we don't want to remove regions on rollback
  end
end

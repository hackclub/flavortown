class AddEnabledUntilToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :enabled_until, :datetime
  end
end

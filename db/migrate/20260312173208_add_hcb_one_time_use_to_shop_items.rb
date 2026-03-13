class AddHCBOneTimeUseToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :hcb_one_time_use, :boolean, default: false
  end
end

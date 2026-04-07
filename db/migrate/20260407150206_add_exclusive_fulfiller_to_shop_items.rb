class AddExclusiveFulfillerToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :exclusive_fulfiller, :boolean,  default: false, null: false
  end
end

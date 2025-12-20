class AddShopRegionToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :shop_region, :string
  end
end

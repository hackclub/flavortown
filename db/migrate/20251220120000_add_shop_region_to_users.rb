class AddShopRegionToUsers < ActiveRecord::Migration[8.0]
  def up
    create_enum :shop_region_type, %w[US EU UK IN CA AU XX]

    remove_column :users, :shop_region, if_exists: true
    add_column :users, :shop_region, :enum, enum_type: :shop_region_type
  end

  def down
    remove_column :users, :shop_region
    drop_enum :shop_region_type
  end
end

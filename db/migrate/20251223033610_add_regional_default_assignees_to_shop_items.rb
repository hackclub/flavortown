class AddRegionalDefaultAssigneesToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :default_assigned_user_id_us, :bigint
    add_column :shop_items, :default_assigned_user_id_eu, :bigint
    add_column :shop_items, :default_assigned_user_id_uk, :bigint
    add_column :shop_items, :default_assigned_user_id_ca, :bigint
    add_column :shop_items, :default_assigned_user_id_au, :bigint
    add_column :shop_items, :default_assigned_user_id_in, :bigint
    add_column :shop_items, :default_assigned_user_id_xx, :bigint
  end
end

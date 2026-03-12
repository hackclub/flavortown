class AddRequiresCookedProjectToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :requires_cooked_project, :boolean, default: false
  end
end

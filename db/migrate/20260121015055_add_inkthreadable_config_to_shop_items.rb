class AddInkthreadableConfigToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :inkthreadable_config, :jsonb
  end
end

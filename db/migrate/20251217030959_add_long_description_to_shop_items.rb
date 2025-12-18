class AddLongDescriptionToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :long_description, :text
  end
end

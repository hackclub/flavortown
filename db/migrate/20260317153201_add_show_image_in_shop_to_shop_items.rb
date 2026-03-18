class AddShowImageInShopToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :show_image_in_shop, :boolean, default: false
  end
end

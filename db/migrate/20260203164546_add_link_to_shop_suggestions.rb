class AddLinkToShopSuggestions < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_suggestions, :link, :string
  end
end

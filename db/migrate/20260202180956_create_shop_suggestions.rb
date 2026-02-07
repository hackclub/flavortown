class CreateShopSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :shop_suggestions do |t|
      t.references :user, null: false, foreign_key: true
      t.text :item
      t.text :explanation

      t.timestamps
    end
  end
end

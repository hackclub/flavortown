class CreateShopOrderReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :shop_order_reviews do |t|
      t.references :shop_order, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :shop_order_reviews, [ :shop_order_id, :user_id ], unique: true
  end
end

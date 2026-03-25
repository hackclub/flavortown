class AddVerdictAndReasonToShopOrderReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_order_reviews, :verdict, :string, null: false
    add_column :shop_order_reviews, :reason, :text, null: false
  end
end

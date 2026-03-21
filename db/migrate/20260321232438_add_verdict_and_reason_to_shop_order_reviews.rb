class AddVerdictAndReasonToShopOrderReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_order_reviews, :verdict, :string
    add_column :shop_order_reviews, :reason, :text
  end
end

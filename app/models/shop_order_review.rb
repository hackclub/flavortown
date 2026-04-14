# == Schema Information
#
# Table name: shop_order_reviews
# Database name: primary
#
#  id            :bigint           not null, primary key
#  reason        :text             not null
#  verdict       :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  shop_order_id :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_shop_order_reviews_on_shop_order_id              (shop_order_id)
#  index_shop_order_reviews_on_shop_order_id_and_user_id  (shop_order_id,user_id) UNIQUE
#  index_shop_order_reviews_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (shop_order_id => shop_orders.id)
#  fk_rails_...  (user_id => users.id)
#
class ShopOrderReview < ApplicationRecord
  has_paper_trail

  belongs_to :shop_order
  belongs_to :user

  VERDICTS = %w[approve reject].freeze

  validates :user_id, uniqueness: { scope: :shop_order_id, message: "has already reviewed this order" }
  validates :verdict, presence: true, inclusion: { in: VERDICTS }
  validates :reason, presence: true
end

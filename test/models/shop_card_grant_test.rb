# == Schema Information
#
# Table name: shop_card_grants
#
#  id                    :bigint           not null, primary key
#  expected_amount_cents :integer
#  hcb_grant_hashid      :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  shop_item_id          :bigint           not null
#  user_id               :bigint           not null
#
# Indexes
#
#  index_shop_card_grants_on_shop_item_id  (shop_item_id)
#  index_shop_card_grants_on_user_id       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (shop_item_id => shop_items.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class ShopCardGrantTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end

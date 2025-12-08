# == Schema Information
#
# Table name: shop_warehouse_packages
#
#  id                        :bigint           not null, primary key
#  frozen_address_ciphertext :text
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  theseus_package_id        :string
#  user_id                   :bigint           not null
#
# Indexes
#
#  index_shop_warehouse_packages_on_theseus_package_id  (theseus_package_id) UNIQUE
#  index_shop_warehouse_packages_on_user_id             (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class WarehousePackageTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end

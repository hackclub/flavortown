# == Schema Information
#
# Table name: users
#
#  id                          :bigint           not null, primary key
#  display_name                :string
#  email                       :string
#  has_gotten_free_stickers    :boolean          default(FALSE)
#  has_roles                   :boolean          default(TRUE), not null
#  magic_link_token            :string
#  magic_link_token_expires_at :datetime
#  projects_count              :integer
#  region                      :string
#  synced_at                   :datetime
#  verification_status         :string           default("needs_submission"), not null
#  votes_count                 :integer
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  slack_id                    :string
#
# Indexes
#
#  index_users_on_magic_link_token  (magic_link_token) UNIQUE
#  index_users_on_region            (region)
#
require "test_helper"

class UserTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end

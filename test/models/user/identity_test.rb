# == Schema Information
#
# Table name: user_identities
#
#  id                       :bigint           not null, primary key
#  access_token_bidx        :string
#  access_token_ciphertext  :text
#  provider                 :string
#  refresh_token_bidx       :string
#  refresh_token_ciphertext :text
#  uid                      :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  user_id                  :integer          not null
#
# Indexes
#
#  index_user_identities_on_access_token_bidx     (access_token_bidx)
#  index_user_identities_on_provider_and_uid      (provider,uid) UNIQUE
#  index_user_identities_on_refresh_token_bidx    (refresh_token_bidx)
#  index_user_identities_on_user_id               (user_id)
#  index_user_identities_on_user_id_and_provider  (user_id,provider) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class User::IdentityTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end

# == Schema Information
#
# Table name: sidequests
#
#  id                 :bigint           not null, primary key
#  description        :string
#  expires_at         :datetime
#  external_page_link :string
#  slug               :string           not null
#  title              :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_sidequests_on_slug  (slug) UNIQUE
#
require "test_helper"

class SidequestTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
